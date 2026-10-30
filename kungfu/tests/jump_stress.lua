local f=0
local failed=false
local done=false
local stage=STAGE or 0
local jumps=0
local previousAir=0
local actions=0
local updates=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addEventCallback(function()
 local t=f%160
 setPad(0,{start=f>=180 and f<190,right=f>=700 and t<80,left=f>=700 and t>=80,up=f>=710 and f%55<30,b=f>=750 and f%39<7,a=f>=750 and f%47<5});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=700 then updates=updates+1 end
 if f>=700 and POWER~=nil then w(0x7c00,POWER);w(0x7c01,0)end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>=700 and r(0x4a6)<128 and (r(0x69)&14)>8 then
  print('BAD-STATE',f,r(0x69),r(0x68),r(0x7c08),r(0x373),r(0x374),r(0x23),r(0x496));failed=true
 end
end,emu.callbackType.exec,0xA826)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if f>=700 and s['ppu.scanline']>=0 and s['ppu.scanline']<240 then
  if not failed then print('VISIBLE-VRAM',f,s['ppu.scanline'],s['cpu.pc'])end
  failed=true
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function()
 if f>=700 and r(0x52)>=0x4f then print('BAD-COMMAND',f,r(0x52));failed=true end
end,emu.callbackType.exec,0x82EE)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 local air=r(0x7c08)
 if f>=700 and air~=0 and previousAir==0 then jumps=jumps+1 end
 previousAir=air
 if r(0x7c38)==1 then actions=actions+1 end
 if failed or f==5000 then
  local out=assert(io.open(TEST_ROOT..'/build/jump-stress-'..stage..'-power-'..(POWER or 0)..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  print('END',f,r(0x69),r(0x68),r(0x51),r(0x4a6))
  assert(not failed,'jump/attack stress must not generate invalid states, background commands or visible VRAM writes')
  assert(jumps>=40 and actions>=100,'stress must execute many jumps and attacks among native enemies')
  assert(updates>=4250,'5000-frame native-enemy replay must retain at least 98.8% of active-frame updates: '..updates)
  assert(KUNGFU_GRAPHICS_CHECKS>3000,'native graphics checks must cover the long controller replay')
  print('PASS floor '..stage..' power '..(POWER or 0)..' 5000-frame native-enemy jump/attack stress, '..jumps..' jumps and '..actions..' extended-attack frames; '..updates..' active-frame updates out of 4300')
  done=true
  emu.stop(failed and 1 or 0)
 end
end,emu.eventType.endFrame)
