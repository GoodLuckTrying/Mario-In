local f=0
local hurt=0
local defeated=false
local done=false
local stage=STAGE or 0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addMemoryCallback(function()
 if f>=700 then
  w(0x7c00,2);w(0x7c01,255)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>700 and emu.getState()['cpu.x']==5 then
  hurt=hurt+1
  if r(0x4a5)>=128 then defeated=true end
 end
end,emu.callbackType.exec,0xC479)
emu.addEventCallback(function()
 if done then return end
 local left=r(0x372)==0
 setPad(0,{start=f>=180 and f<190,left=f>=700 and left,right=f>=700 and not left,b=f>=700 and f%8<7})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==700 then assert(r(0x5f)==stage,'floor fixture')end
 if f==3000 or defeated then
  print('Boss fixture floor '..stage..' hits '..hurt..' dead '..tostring(defeated)..' x '..r(0xe5)..':'..r(0xd4)..' direction '..r(0x372)..' hp '..r(0x4a5))
  assert(defeated and hurt>=7,'Controller-fired fireballs must defeat the native boss')
  print('PASS native boss floor '..stage)
  done=true
  emu.stop(0)
 end
end,emu.eventType.endFrame)
