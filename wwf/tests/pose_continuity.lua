-- Real two-controller movement, including fractional depth updates and rests.
-- Health is replenished to keep the visual stress replay in a single bout;
-- positions, native action/script state, and animation state are never seeded.
MODE=2
dofile(TEST_ROOT..'/tests/common.lua')
local dirs={{down=true},{right=true,down=true},{right=true},{right=true,up=true},{up=true},{left=true,up=true},{left=true},{left=true,down=true}}
local file=assert(io.open(TEST_ROOT..'/build/streamed-poses.chr','rb'))
local stream=file:read('*a');file:close()
local checked=0;local pixels=0;local drawn=nil
local seen={{},{}}
local function direction(t,opposite)
 if t<100 or t>=1124 then return{}end
 local z=t-100
 if z%128>=64 then return{}end
 return dirs[(z//128+opposite)%8+1]
end
function input(t)return direction(t,0)end
function input2(t)return direction(t,4)end
emu.addMemoryCallback(function()
 if r(0xc)==0 and first then w(0x79,200);w(0x7a,200)end
end,emu.callbackType.exec,H.UpdateBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first then return end
 local t=f-first
 drawn={}
 for p=0,1 do
  local pose=r(0x4d8+p)
  drawn[p+1]={pose=pose,group=r(0x4ea+p)}
  if t>=100 and t<1124 then
   local z=t-100;local offset=z%128
   -- Exclude the two-frame packet/control handoff at a direction change.
   if offset>=12 and offset<=60 or offset>=80 and offset<=120 then
    local moving=offset<=60
    local d=dirs[(z//128+(p==0 and 4 or 0))%8+1]
    local diagonal=(d.left or d.right)and(d.up or d.down)
    local valid
    if diagonal then
     local base=d.up and 19 or 17
     valid=pose==base or moving and pose==base+1
    elseif d.up or d.down then
     local base=d.up and 14 or 11
     valid=moving and(pose==base+1 or pose==base+2)or not moving and pose==base
    else valid=moving and pose>=1 and pose<=3 or not moving and pose==0 end
    assert(valid,'wrong/flickering movement pose at frame '..t..' body '..p..': '..pose)
    if d.left or d.right then
     -- At a rope, native turning takes several script steps before the
     -- wrestler can move. Follow the resolved facing, not the new input.
     local left=r(0x3a+p)&1~=0
     local expectedFlip=diagonal and not left or not diagonal and left
     assert((r(0x4f3+p)&64~=0)==expectedFlip,'body must match resolved native facing, frame '..t..' body '..p)
    end
    seen[p+1][pose]=true;checked=checked+1
   end
  end
 end
end,emu.callbackType.exec,0xad6a)
-- Read the real CHR and hardware OAM after the HUD/ring split has completed.
-- This catches a correct cache being overwritten before it is displayed.
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not drawn then return end
 for p=0,1 do local d=drawn[p+1]
  if d.pose>=11 then
   for cell=0,11 do
    local at=d.group+cell*4
    local sy=emu.read(at,emu.memType.nesSpriteRam)
    local tile=emu.read(at+1,emu.memType.nesSpriteRam)
    if sy<240 then for n=0,15 do
     local actual=emu.read(0x1000+tile*16+n,emu.memType.nesPpuDebug)
     local expected=stream:byte((d.pose-11)*192+cell*16+n+1)
     assert(actual==expected,'displayed pose packet changed at frame '..(f-first)..' body '..p)
     pixels=pixels+1
    end end
   end
  end
 end
 drawn=nil
end,emu.callbackType.exec,0xadfe)
function tick(t)
 if t==1200 then
  assert(checked==1440,'both brothers must complete all eight directions and idle rests: '..checked)
  assert(pixels>50000,'exercise sustained visible hardware CHR')
  for p=1,2 do for _,pose in ipairs({0,1,2,3,11,12,13,14,15,16,17,18,19,20})do
   assert(seen[p][pose],'both brothers must show pose '..pose)
  end end
  finish('1440 direction/idle/facing checks, both brothers, eight directions, resolved actions, and post-split hardware CHR')
 end
end
