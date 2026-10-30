local f=0;local started=nil;local spawned=0;local bounces=0;local old={};local nativeShots=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=started and f-started or -1
 setPad(0,{start=not started and f>=120 and f%60<2,b=t>=20 and t%80<2})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x10)~=11 then return end
 started=started or f
 for i=0,5 do w(0x650+i*16,0)end
 w(0x63,128)
end,emu.callbackType.exec,0xF28D)
emu.addMemoryCallback(function()
 if not started then return end
 for _,o in ipairs({0,16})do
  local a=H.FB+o;local active=r(a);local vy=r(a+3)
  if active~=0 and not old[o]then spawned=spawned+1 end
  if active~=0 and vy==253 and old[o] and old[o].vy<128 then bounces=bounces+1 end
  old[o]=active~=0 and {vy=vy}or nil
 end
 for o=0,24,3 do if r(0x6e+o)>=128 then nativeShots=true end end
end,emu.callbackType.exec,H.FireUpdate)
emu.addEventCallback(function()
 f=f+1
 if started and f-started>=650 then
  assert(spawned>=5,'independent Mario fireballs spawn repeatedly: '..spawned)
  assert(bounces>=4,'Mario fireballs bounce on native floor: '..bounces)
  assert(nativeShots,'original Karnov attack remains functional')
  assert(r(0x68)&0x80==0,'isolated shots must not damage Mario')
  print('PASS native Karnov floor, '..spawned..' fireballs, '..bounces..' bounces, original attack retained');emu.stop(0)
 end
 assert(f<2500,'bounded fire replay')
end,emu.eventType.endFrame)
