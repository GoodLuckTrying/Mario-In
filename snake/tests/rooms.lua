-- Open a native bonus portal in a deterministic actor slot; run the native
-- room transition, then its native return path. Keep Mario's power through both.
local f=0
local p=PLAYER or 0
local seeded=false
local entered=nil
local returning=false
local calls=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=f>=700 and f<710});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 calls=calls+1
 if f>=850 and not seeded then
  seeded=true;w(0x7000+p,2);w(0x7004+p,1);w(0x3b0,p)
  for _,a in ipairs({0x4d7,0x4c3,0x4ff,0x4eb,0x527,0x513})do w(a+2,r(a+p))end
  w(0x49d,0x23);w(0x5b5,0);w(0x577+2,0)
 end
end,emu.callbackType.exec,H.SceneGate)
emu.addMemoryCallback(function()
 if entered~=nil and f-entered>=150 and not returning then
  returning=true
  local state=emu.getState();state['cpu.pc']=0xC1EC;emu.setState(state)
 end
end,emu.callbackType.exec,0x8CCF)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if f>=800 then w(0x40d,255);w(0x40e,255)end
 if r(0xbd)==1 and entered==nil then entered=f end
 if f==1800 then
  assert(entered~=nil and returning,'native bonus room must enter and return')
  assert(r(0xbd)==0,'must return to the original playfield')
  assert(r(0x7000+p)==2 and r(0x7004+p)==1,'bonus room entry/return must preserve form and meal progress')
  assert(calls>600,'room code and native gameplay must continue')
  print('PASS P'..p..' native bonus room entry/return preserves flower and meal progress')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
