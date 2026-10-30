-- Trigger one native fatal hit, then repeatedly try to damage the corpse.
-- Let the original fall, actor removal, life decrement and restart/game-over run.
local f=0
local stage=STAGE or 0
local fired=false
local removed=false
local finished=false
local beforeLives
local contacts=0
local late=0
local falling=0
local lastY=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addEventCallback(function()
 setPad(0,{start=f>=180 and f<190,up=AIR==1 and f>=790 and f<850});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<800 then for i=0,5 do w(0x80+i,0)end end
 if f>=800 and not fired then
  fired=true
  if LAST==1 then w(0x5c,1)end
  beforeLives=r(0x5c)
  w(0x7c00,0);w(0x7c01,0);w(0x7c0c,0);w(0x4a6,0)
 end
 if fired and not finished and (r(0x4a6)==0 or r(0x4a6)>=128) then
  contacts=contacts+1;w(0x37a,8)
  local s=emu.getState();s['cpu.x']=6;s['cpu.pc']=H.DamageGate;emu.setState(s)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if not fired or r(0x4a6)<128 then return end
 if r(0x86)==0 then
  removed=true
  for a=0x218,0x24c,4 do assert(r(a)>=240,'removed player and projectiles must stay hidden')end
 else
  assert(not removed,'another hit must not reactivate a removed corpse')
  local y=r(0xb6)
  if lastY~=nil then assert(math.abs(y-lastY)<16,'death fall must never wrap to the top')end
  lastY=y;falling=falling+1
  for a=0x218,0x234,4 do assert(r(a)>=240 or r(a)>=y+15,'death sprite rows must not wrap to the top')end
 end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then late=late+1 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 if finished then return end
 f=f+1
 if fired and r(0x5c)==beforeLives-1 then
  assert(removed and falling>10 and contacts>20,'the native death sequence must complete despite repeated damage')
  assert(late==0,'death DMA must stay in vblank')
  if LAST==1 then
   if r(0x51)==4 then finished=true end
  elseif r(0x50)==1 and r(0x51)==2 and r(0x4a6)==48 then
   assert(r(0x7c00)==0 and r(0xb6)==135,'restart must be a living small Mario at ground height')
   finished=true
  end
  if finished then
   print('PASS floor '..stage..' '..(AIR==1 and 'air' or 'ground')..' death ignores '..contacts..' repeated hits, clips sprites, and reaches '..(LAST==1 and 'game over' or 'the next life'))
   emu.stop(0)
  end
 end
 assert(f<1700,'death must reach next life/game over without a loop')
end,emu.eventType.endFrame)
