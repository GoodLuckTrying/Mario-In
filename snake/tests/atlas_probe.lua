local f=0
local counts={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
for _,k in ipairs({'SetupAtlas','DrawStart','DrawScene','DrawGate','PlayerGate'})do
 emu.addMemoryCallback(function()counts[k]=(counts[k]or 0)+1 end,emu.callbackType.exec,H[k])
end
emu.addEventCallback(function()setPad(0,{start=f>=700 and f<710});setPad(1,{})end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if f%200==0 then
  print('STATE',f,r(0x11),r(0x10),r(0x49b),r(0x49c),r(0xe2),r(0x7094),r(0x7093),r(0x7091),r(0x5b3),r(0x5b4),r(0x6000),r(0x6001),r(0x7200))
  for k,v in pairs(counts)do print(k,v)end
 end
 if f==1000 then
  local o=assert(io.open(TEST_ROOT..'/build/atlas-probe-ram.bin','wb'))
  for a=0,0x7fff do o:write(string.char(r(a)))end;o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
