-- Sustained native Diskarmor plus fireballs while the real side-view camera moves.
local f=0;local started=nil;local late=0;local scrolled=0;local bounces=0;local alive=0;local old={};local disks=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=started and f-started or -1
 setPad(0,{start=not started and f>=120 and f%60<2,right=t>=50 and t<350,b=t>=50 and t%30<2})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 started=started or f
 -- Isolate terrain/attack timing from enemy damage; keep the native weapon live.
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
end,emu.callbackType.exec,0x9b9a)
emu.addMemoryCallback(function(a,v)
 if not started or f-started<30 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled'])then
  late=late+1
 end
end,emu.callbackType.write,0x2005,0x2007)
emu.addMemoryCallback(function(a,v)
 if not started or f-started<30 or(v&0x18)==0 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then late=late+1 end
end,emu.callbackType.write,0x2001)
emu.addMemoryCallback(function()
 if not started then return end
 if r(0x17)>0 then scrolled=scrolled+1 end
 if r(0x493)~=0 then disks=disks+1 end
 for _,o in ipairs({0,16})do
  local a=0x7e00+o;local age=r(a);local vy=r(a+3)
  if age~=0 then
   if old[o] and old[o].age+1==age and old[o].vy<128 and vy==253 then bounces=bounces+1 end
   if age>=12 and vy>=128 then alive=alive+1 end
  end
  old[o]={age=age,vy=vy}
 end
end,emu.callbackType.exec,0x9b9a)
emu.addEventCallback(function()
 f=f+1
 if started and f-started==600 then
  assert(late==0,'all scroll/address/data writes finish before visible rendering: '..late)
  assert(scrolled>150 and disks>50,'moving native camera and Diskarmor exercised')
  assert(bounces>=6 and alive>=12,'fireballs survive their rebound and bounce repeatedly: '..bounces..' / '..alive)
  print('PASS moving/fire stress: '..scrolled..' scrolling updates, '..bounces..' rebounds, zero late PPU writes');emu.stop(0)
 end
 assert(f<2000,'bounded weapon/scroll replay')
end,emu.eventType.endFrame)
