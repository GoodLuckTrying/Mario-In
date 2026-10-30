local f=0
local entered=nil
local bossSeed=nil
local defeated=nil
local keySeed=nil
local clear=false
local nextStage=false
local boots=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function place(x,kind,flags,dx,y)
 w(0x4f0+x,flags);w(0x631+x,kind);w(0x647+x,0);w(0x61d+x,0);w(0x607+x,0);w(0x65d+x,0);w(0x5f1+x,12)
 w(0x5af+x,r(0x5af)+dx);w(0x583+x,r(0x583));w(0x599+x,y);w(0x56d+x,r(0x56d));w(0x5c5+x,0);w(0x5db+x,0)
 w(0x554+x,r(0x554)+dx);w(0x509+x,y-r(0x67));w(0x53b+x,1);w(0x522+x,0xb0)
end
emu.addMemoryCallback(function()boots=boots+1;assert(boots==1,'native level clear must not reset ROM')end,emu.callbackType.exec,H.Boot)
emu.addMemoryCallback(function()if not entered then w(0xc2,2)end end,emu.callbackType.exec,0xd0f7)
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,b=bossSeed~=nil and not defeated and t%24<8});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f
 if r(0xcf)==1 then nextStage=true end
 w(0x4f0,(r(0x4f0)&0xfe)|0x40);w(0x647,0)
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 if not entered then return end
 if not bossSeed and f-entered>60 then
  for x=1,21 do w(0x4f0+x,0)end
  place(1,5,0x80,40,r(0x599));w(0x648,9);w(0xc3,1);w(0xc4,0);bossSeed=f
 elseif defeated and not keySeed and f-defeated>75 then
  for x=1,21 do w(0x4f0+x,0)end
  w(0x4f0,0x80);w(0x647,0)
  w(0x5af,120);w(0x583,13);w(0x599,184);w(0x56d,0);w(0x509,184);w(0x554,96);w(0x64,24);w(0x65,13);w(0x67,0);w(0x68,0)
  w(H.M_STATE,0);w(H.M_VY,0);w(H.M_SMB_X_SPEED,0);w(H.M_SMB_X_FORCE,0)
  place(1,0x1e,0x82,0,184);keySeed=f
 end
end,emu.callbackType.exec,0x9cc8)
emu.addMemoryCallback(function()
 local x=emu.getState()['cpu.x']
 if bossSeed and r(0x631+x)==5 then
  assert(r(0x647+x)>=10,'native weapon supplies the final boss damage')
  defeated=defeated or f
 end
end,emu.callbackType.exec,0xf6f6)
emu.addMemoryCallback(function()if keySeed then clear=true;assert(r(H.M_NATIVE)==1,'native key hands Mario to level-clear script')end end,emu.callbackType.exec,N.PlayerLevelClear)
emu.addEventCallback(function()
 f=f+1
 if nextStage then
  assert(defeated and keySeed and clear,'boss/native key/door clear all exercised')
  print('PASS native weapon boss finishing hit, native defeat, key collision, door script and next-stage load without reset');emu.stop(0)
 end
 assert(f<4500,'boss/key/exit fixture completes; boss '..tostring(defeated)..' key '..tostring(keySeed)..' clear '..tostring(clear)..' stage '..r(0xcf)..' x '..r(0x583)..':'..r(0x5af))
end,emu.eventType.endFrame)
