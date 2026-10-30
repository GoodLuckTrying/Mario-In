local f=0;local started=nil;local spawned=0;local bounces=0;local old={};local disk=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=started and f-started or -1
 setPad(0,{start=not started and f>=120 and f%60<2,b=t>=20 and t%80<2})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 started=started or f
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
end,emu.callbackType.exec,0x9B9A)
emu.addMemoryCallback(function()
 if not started then return end
 for _,o in ipairs({0,16})do
  local a=H.FB+o;local active=r(a);local vy=r(a+3)
  if active~=0 and not old[o]then spawned=spawned+1 end
  if active~=0 and vy==253 and old[o]and old[o].vy<128 then bounces=bounces+1 end
  old[o]=active~=0 and {vy=vy}or nil
 end
 if r(0x493)~=0 then disk=true end
end,emu.callbackType.exec,H.FireUpdate)
emu.addEventCallback(function()
 f=f+1
 if started and f-started>=700 then
  assert(spawned>=5,'independent Mario fireballs spawn repeatedly: '..spawned)
  assert(bounces>=4,'Mario fireballs bounce on native floor: '..bounces)
  assert(disk,'original Diskarmor remains functional')
  assert(r(0x492)&0x20==0,'isolated shots must not damage Mario')
  print('PASS native Rygar floor, '..spawned..' fireballs, '..bounces..' bounces, Diskarmor retained');emu.stop(0)
 end
 assert(f<2500,'bounded fire replay')
end,emu.eventType.endFrame)
