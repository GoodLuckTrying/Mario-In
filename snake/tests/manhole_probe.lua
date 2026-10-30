local f=0
local calls=0
local loaded=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()calls=calls+1 end,emu.callbackType.exec,0x918B)
emu.addMemoryCallback(function()
 if f<10 or loaded then return end
 loaded=true
 local file=assert(io.open(TEST_ROOT..'/build/manhole-recent/Savestate.mss','rb'))
 assert(emu.loadSavestate(file:read('*a')),'load recent game state');file:close()
 if REPAIR then
  file=assert(io.open(TEST_ROOT..'/build/hack.bin','rb'))
  local code=file:read('*a');file:close()
  for i=1,#code do w(0x5fff+i,code:byte(i))end
  local state=emu.getState();state['cpu.pc']=0xCCD7;emu.setState(state)
 end
 print('AFTER LOAD PC',emu.getState()['cpu.pc'],'SCENE',r(0x11),r(0x10),'KIND',r(0x49b))
end,emu.callbackType.exec,0xD2CD)
emu.addEventCallback(function()setPad(0,{b=f>=60 and f<65,right=f>=180 and f<220,a=f>=300 and f<320});setPad(1,{})end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f%30==0 then
  local s=emu.getState()
  print(string.format('F%d PC%04X calls%d frame%02X scene%02X%02X C0%02X C5%02X BD%02X AF%02X pos%02X%02X/%02X%02X/%02X%02X vel%02X/%02X kind%02X/%02X power%02X/%02X w%02X life%02X tl%02X p%02X eat%02X 65%02X mask%02X',f,s['cpu.pc'],calls,r(2),r(0x11),r(0x10),r(0xc0),r(0xc5),r(0xbd),r(0xaf),r(0x4c3),r(0x4d7),r(0x4eb),r(0x4ff),r(0x513),r(0x527),r(0x5c7),r(0x5db),r(0x49b),r(0x49c),r(0x7000),r(0x7001),r(0x59f),r(0x3df),r(0x499),r(0x41f),r(0x485),r(0x65),r(0x01)))
 end
 if f==400 then
  local file=assert(io.open(TEST_ROOT..'/build/manhole-ram.bin','wb'))
  for a=0,0x7ff do file:write(string.char(r(a)))end;file:close()
  file=assert(io.open(TEST_ROOT..'/build/manhole-resume.png','wb'));file:write(emu.takeScreenshot());file:close()
  if REPAIR then assert(calls>200,'exact saved lock must resume gameplay');print('PASS saved manhole lock resumes with bounded lookup')end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
