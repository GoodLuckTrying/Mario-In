-- Render native cover/door/elevator poses alongside every pair of player
-- forms. The shared graphics oracle compares the displayed CHR to the original.
local stage=STAGE or 0
local f=0
local selected=false
local current=nil
local renders=0
local displayed=0
local variants={}
local poses={0x15,0x16,0x17,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,0x30}
local total=9*6*#poses
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 if not selected then w(0xaa,(stage-1)&255);selected=true end
end,emu.callbackType.exec,0x82BF)
emu.addEventCallback(function()
 setPad(0,{start=f>=700 and f<710});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<820 or displayed>=total then return end
 local pair=math.floor(displayed/(6*#poses))
 local mode=math.floor(displayed/#poses)%6
 local pose=poses[displayed%#poses+1]
 current={pose=pose,pair=pair,mode=mode}
 for p=0,1 do
  local power=p==0 and pair%3 or math.floor(pair/3)
  w(0x49b+p,p+1);w(0x7000+p,power);w(0x7008+p,1)
  w(0x40d+p,0);w(0x3b7+p,64+p*56);w(0x3cb+p,160);w(0x577+p,0)
  w(0x5b3+p,p);w(0x5c7+p,mode>=4 and 2 or 255)
  w(0x16+p,mode>=2 and 1 or 0);w(0x7006+p,mode%2==0 and 1 or 2)
 end
 w(3,mode%2*8)
 for slot=2,19 do w(0x49b+slot,0);w(0x5b3+slot,128)end
 w(0x49d,6);w(0x5b5,0);w(0x3b9,192);w(0x3cd,144);w(0x579,0)
 local a=pair%3;local b=math.floor(pair/3)
 if a==2 and b==2 then current.variant=1
 elseif a~=2 and b~=2 then current.variant=0
 else
  local firepose=mode>=4 and 32 or (mode==2 and 24 or 16)
  current.variant=2+(firepose-16)//4+mode%2
 end
 renders=renders+1
end,emu.callbackType.exec,H.DrawScene)
emu.addMemoryCallback(function()
 if current and emu.getState()['cpu.y']==2 then
  current.called=true
  w(0x4b1,current.pose);w(0x75,192);w(0x5c,144)
 end
end,emu.callbackType.exec,H.DrawGate)
emu.addMemoryCallback(function(address)
 if current and address%4==1 and emu.getState()['cpu.pc']==0xFEEB and r(0x86)==2 then
  current.cell=(address-0x201)//4
 end
end,emu.callbackType.write,0x201,0x2fd)
emu.addMemoryCallback(function()
 if current then
  assert(current.called,'native renderer must draw cover/door pose')
  assert(current.cell~=nil and r(0x200+current.cell*4)<240,'cover/door must have a visible sprite')
  local group=stage<4 and 0 or (stage<8 and 1 or 2)
  assert(r(0x70a0)==8 or r(0x70a0)==10,'display uses a complete physical sprite bank')
  variants[current.variant]=true;displayed=displayed+1
  if current.pair==8 and current.mode==0 and current.pose==0x16 then
   local out=assert(io.open(TEST_ROOT..'/build/covers-fire-stage-'..stage..'.png','wb'))
   out:write(emu.takeScreenshot());out:close()
  end
  current=nil
 end
end,emu.callbackType.exec,0xFF9C)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if displayed==total then
  for _,v in ipairs({0,1,2,3,4,6,7})do assert(variants[v],'every reachable atlas variant must display '..v)end
  assert(GRAPHICS_CHECKS>3000,'native rendered sprite checks must run throughout animation fixture')
  print('PASS stage '..stage..' '..displayed..' cover/door poses with all form pairs and reachable animation atlases')
  emu.stop(0)
 end
 assert(f<2500,'graphics fixture must finish')
end,emu.eventType.endFrame)
