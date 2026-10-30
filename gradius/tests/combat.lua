-- Real opening waves, controller-fired fireballs, no enemy or shot RAM fixtures.
local f=0
local kills=0
local shots=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f>=200 and f<210,a=f>=420,right=f>=430 and f<510,
  up=f>=420 and r(0x320)>72,left=f>=1100 and f<1180})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function() if f>420 then kills=kills+1 end end,emu.callbackType.exec,0xc0a6)
emu.addMemoryCallback(function() if f>420 then shots=shots+1 end end,emu.callbackType.exec,H.SpawnAEnd)
emu.addEventCallback(function()
 f=f+1
 if f==420 then w(0x7005,1) end
 if f==1600 then
  assert(kills>0 and shots>10,'Controller-fired fireballs must kill actual stage enemies')
  assert(r(0x100)==1,'Natural-wave replay must remain playable')
  print('PASS controller fireballs, native waves, '..kills..' kills and '..shots..' shots');emu.stop(0)
 end
end,emu.eventType.endFrame)
