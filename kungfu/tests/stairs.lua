-- Defeat the real boss through controller fireballs, walk to the exit, then
-- let the entire native staircase/bonus/new-floor sequence run unchanged.
local stage=STAGE or 0
local power=POWER or 2
local f=0
local selected=false
local entered=nil
local bossDead=false
local climbFrames=0
local topFrames=0
local low=255
local high=0
local seen={}
local preserved=false
local saved=false
local done=false
local nativeActor=false
local file=assert(io.open(TEST_ROOT..'/build/mario-frames.chr','rb'))
local frames=file:read('*a');file:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 if not selected then w(0x58,stage);selected=true end
end,emu.callbackType.exec,0x8522)
emu.addMemoryCallback(function()
 if f>=700 and entered==nil then w(0x7c00,2);w(0x7c01,1)end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if emu.getState()['cpu.x']==5 and r(0x4a5)>=128 then bossDead=true end
end,emu.callbackType.exec,0xC479)
emu.addMemoryCallback(function()
 if entered~=nil and r(0x5f)==stage+1 then
  assert(r(0x7c00)==power,'native floor initialization must preserve Mario power')
  preserved=true
 end
end,emu.callbackType.exec,0x85F2)
emu.addEventCallback(function()
 if done then return end
 local left=r(0x372)==0
 local go=f>=700 and entered==nil and r(0x51)==2
 setPad(0,{start=f>=180 and f<190,left=go and left,right=go and not left,b=go and f%8<7});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(address,value)
 if entered~=nil and r(0x51)==3 and r(0x60)==3 then
  assert(value&8==0,'stairs must keep Mario in the gameplay sprite pattern table')
 end
end,emu.callbackType.write,0x2000)
emu.addMemoryCallback(function()
 if entered~=nil and r(0x50)==1 and r(0x51)==5 then
  for a=0x218,0x24c,4 do assert(r(a)>=240,'Sylvia intermission must not display a stray Mario')end
 end
 if entered==nil or r(0x51)~=3 then return end
 local phase=r(0x60)
 if phase==3 and f-entered>2 then
  climbFrames=climbFrames+1
  local pose=r(0x7c0f)
  assert(pose==(power==0 and 33 or 31) or pose==(power==0 and 34 or 32),'stairs must use the size-appropriate Mario walking poses')
  seen[pose]=true
  assert(r(0x7c08)==0 and r(0x7c01)==0 and r(0x7c38)==0,'stairs must clear frozen jump/blink/attack state')
  assert(r(0x7c24)==0 and r(0x7c25)==0,'stairs must clear frozen projectiles')
  assert(r(0x7c00)==power,'stairs must retain power')
  assert(r(0x10)&8==0,'displayed stairs sprite table must contain Mario')
  assert(r(0x218)<240,'Mario must remain visible during the climb')
  assert((r(0x21a)&64)==(r(0xc6)==0 and 64 or 0),'Mario must face the scripted stair direction rather than held input')
  if r(0x86)==1 then nativeActor=true end
  low=math.min(low,r(0xb6));high=math.max(high,r(0xb6))
  for cell=0,7 do
   local tile=r(0x219+cell*4);local flip=r(0x21a+cell*4)&64
   local logical=flip~=0 and cell~1 or cell
   for n=0,15 do
    local expected=frames:byte(({[31]=0,[32]=1,[33]=12,[34]=13})[pose]*128+logical*16+n+1)
    assert(emu.read(tile*16+n,emu.memType.nesPpuDebug)==expected,'actual staircase CHR must be the original SMB Mario walking art')
   end
  end
 elseif phase==4 or phase==5 then
  topFrames=topFrames+1
  for a=0x218,0x24c,4 do assert(r(a)>=240,'Mario must leave the screen after finishing the staircase')end
 end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'stair sprite DMA must stay in vblank')
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if r(0x51)==3 and entered==nil then
  assert(bossDead,'controller-fired native boss defeat must precede the staircase')
  entered=f;w(0x7c00,power)
  -- Carry difficult final-combat state into the cinematic. Rendering must
  -- clear it without disturbing the native stair actor or power state.
  w(0x7c08,1);w(0x7c01,120);w(0x7c38,1);w(0x7c24,40);w(0x7c25,40)
 end
 if entered~=nil and climbFrames>=96 and not saved then
  saved=true
  local out=assert(io.open(TEST_ROOT..'/build/stairs-stage-'..stage..'-power-'..power..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if entered~=nil and r(0x5f)==stage+1 and r(0x50)==1 and r(0x51)==2 then
  assert(climbFrames>150 and nativeActor and high-low>=64,'the native actor must complete the actual upward climb')
  assert(seen[power==0 and 33 or 31] and seen[power==0 and 34 or 32],'both walking animation frames must display')
  assert(topFrames>50 and preserved,'native bonus and new-floor initialization must finish')
  assert(KUNGFU_GRAPHICS_CHECKS>1000,'displayed CHR and VRAM commands must be checked through the transition')
  print('PASS floor '..stage..' power '..power..' controller boss/exit, '..climbFrames..' native stair frames with SMB walking CHR, bonus and next floor')
  done=true;emu.stop(0)
 end
 assert(f<6500,'stairs must finish the native next-floor transition')
end,emu.eventType.endFrame)
