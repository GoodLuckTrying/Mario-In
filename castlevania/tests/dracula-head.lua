-- Controlled placements; all head cooldown expiry and damage are native.
local frame=0
local pending=nil
local checks=0
local phase='boot'
local tick=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
local expected={[700]=60,[704]=60,[711]=56,[740]=64,[751]=60,[780]=62,[784]=62,[791]=60}
local function player()
 w(0x6001,1);w(0x600d,90);w(0x5b,0);w(0x45,64);w(0x46c,1)
 w(0x3f,145);w(0x354,145);w(0x38c,120);w(0x40,120);w(0x41,0);w(0x450,0)
 for _,a in ipairs({0x6002,0x6003,0x6004,0x6005,0x6006,0x6013,0x6070,0x6071,0x6072,0x6073,0x6074,0x6075,0x607f}) do w(a,0) end
 w(0x6020,0);w(0x6021,0);w(0x603e,13);w(0x6039,0)
end
emu.addEventCallback(function()emu.setInput({start=frame==120},0)end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if phase~='play' then return end
 tick=tick+1
 local n=699+tick
 if not expected[n] then return end
 if n==700 or n==740 or n==780 then
  for x=3,27 do
   w(0x434+x,0);w(0x60a0+x,0)
   for _,base in ipairs({0x300,0x31c,0x338,0x354,0x370,0x38c,0x3a8,0x3c4,0x3e0,0x3fc,0x418,0x450,0x46c,0x488,0x4a4,0x4c0,0x4dc,0x4f8,0x514,0x530,0x54c,0x568,0x584}) do w(base+x,0) end
  end
  w(0x1a8,0);w(0x1a9,64);w(0x7a,n==780 and 1 or 0)
  w(0x434+7,29);w(0x38c+7,160);w(0x354+7,168);w(0x46c+7,6);w(0x54c+7,200);w(0x4c0+7,41);w(0x31c+7,208)
  w(0x434+8,4);w(0x300+8,128);w(0x38c+8,155);w(0x354+8,n==780 and 136 or 141)
  if n==740 then w(0x488+8,128);w(0x568+8,8) end
 end
 -- Reposition the native weak point for each strike without resetting either
 -- hurt counter or accumulated boss health between hits in the same case.
 w(0x38c+7,160);w(0x354+7,168);w(0x46c+7,6)
 w(0x434+8,4);w(0x300+8,128);w(0x38c+8,155);w(0x354+8,r(0x7a)==1 and 136 or 141)
 player();pending=n
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if not pending then return end
 local n=pending;pending=nil
 assert(r(0x1a9)==expected[n],'Dracula head frame '..n..' HP '..r(0x1a9)..' expected '..expected[n])
 if n==700 or n==711 or n==751 or n==780 or n==791 then
  assert(r(0x570)==8 and r(0x490)>=128,'Accepted head hit must set its native eight-update cooldown')
 end
 if n==780 or n==791 then assert(r(0x56f)==8,'Second form must retain its native body cooldown') end
 checks=checks+1;print('Dracula head frame '..n..' passed')
end,emu.callbackType.exec,0xe8f0)
emu.addEventCallback(function()
 frame=frame+1
 if frame==650 then
  w(0x28,18);w(0x600b,18);w(0x46,1);w(0x48,0);w(0xe2,0);w(0x2d,0);w(0x2e,0);w(0x2f,0);w(0x18,5);w(0x19,0);phase='loading'
 end
 if phase=='loading' and r(0x18)==5 and r(0x19)==6 then phase='play' end
 if phase=='play' and tick>=107 then
  assert(checks==8 and r(0x570)==0 and r(0x56f)==0,'Native body AI must naturally expire both head and body cooldowns')
  print('Dracula head passed: repeated hits, blocked cooldown hits, native timer expiry and both forms');emu.stop(0)
 end
 assert(frame<1000,'Dracula head fixture timeout')
end,emu.eventType.endFrame)
