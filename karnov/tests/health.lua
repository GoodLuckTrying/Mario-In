local f=0;local started=nil;local injured=false;local dying=false;local spawns=0;local seeded=0;local last=-999
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=not started and f>=120 and f%60<2})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 spawns=spawns+1
 if spawns>1 then assert(injured and dying,'native injury and death precede respawn')end
end,emu.callbackType.exec,H.PlayerSpawnReset)
emu.addMemoryCallback(function()
 if r(0x10)~=11 then return end
 started=started or f
 if r(0x68)&128~=0 then injured=true end
 if r(0x62)&31>=25 then dying=true end
 if r(0x62)&31<9 and r(0x68)&64==0 and f-last>=180 and not dying then
  for i=0,5 do w(0x650+i*16,0)end
  w(0x650,128);w(0x651,4);w(0x652,r(0x63));w(0x653,r(0x64)-8);w(0x654,1);w(0x655,0)
  last=f;seeded=seeded+1
 end
end,emu.callbackType.exec,0xF28D)
emu.addEventCallback(function()
 f=f+1
 if spawns>=2 and started and f-last>200 then
  assert(injured and dying and seeded>=2,'two native contacts cause injury then death')
  assert(r(H.M_STATE)==0,'fresh life resets private movement')
  print('PASS native two-hit health, death and fresh-life initialization');emu.stop(0)
 end
 assert(f<2200,'bounded native health/death replay; spawns '..spawns..' injured '..tostring(injured)..' dying '..tostring(dying))
end,emu.eventType.endFrame)
