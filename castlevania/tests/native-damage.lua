-- Isolated native damage dispatch; this does not run a complete boss battle.
local frame=0
local scenario=nil
local actor=8
local hits,stomps=0,0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame>=700 and frame<=760 and (frame-700)%10==0 then
  scenario=math.floor((frame-700)/10)
  for x=3,22 do w(0x434+x,0);w(0x60a0+x,0) end
  for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530}) do w(base+actor,0) end
  w(0x6001,2);w(0x600d,0);w(0x5b,0);w(0x45,64);w(0x46c,0);w(0x3f,176);w(0x354,176)
  w(0x1a8,0);w(0x1a9,64);w(0x7a,0)
  w(0x434+actor,0x18);w(0x38c+actor,120);w(0x354+actor,124)
  w(0x6020,1);w(0x6021,0);w(0x6022,116);w(0x6024,120);w(0x6026,0);w(0x6050,0);w(0x6028,0);w(0x602a,0);w(0x602c,50)
  hits=r(0x6046);stomps=r(0x6045)
  if scenario==1 then w(0x488+actor,128);w(0x568+actor,8)
  elseif scenario==2 then
   w(0x6020,0);w(0x46c,1);w(0x354+actor,160);w(0x38c+actor,r(0x38c))
   local top=160-r(0xE46B+2*0x18)
   w(0x3f,top-15);w(0x354,top-15);w(0x6008,top-18);w(0x6005,2);w(0x6004,0)
  elseif scenario==3 then
   w(0x434+actor,0x1A);w(0x584+actor,32)
   w(0x434+7,0x1A);w(0x584+7,32);w(0x38c+7,240);w(0x354+7,124);w(0x300+7,0);w(0x488+7,0)
  elseif scenario==4 then w(0x434+actor,4);w(0x300+actor,128);w(0x7a,1)
  elseif scenario==5 then
   w(0x434+actor,0x2F);w(0x584+actor,0)
  elseif scenario==6 then
   w(0x434+actor,4);w(0x60a0+actor,3);w(0x60c0+actor,100)
  end
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if scenario==nil then return end
 local n=scenario
 scenario=nil
 if n==0 then
  assert(r(0x1a9)==60 and r(0x488+actor)>=128 and r(0x6046)==hits+1,'Fireball must use native boss damage and cooldown')
 elseif n==1 then
  assert(r(0x1a9)==64 and r(0x6046)==hits and r(0x6020)==1,'Boss hurt cooldown must prevent repeat hits')
 elseif n==2 then
  assert(r(0x1a9)==60 and r(0x6045)==stomps+1 and r(0x6005)==252 and r(0x6001)==2 and r(0x45)==64,'Boss stomp must damage, bounce and preserve player power')
 elseif n==3 then
  assert(r(0x584+actor)==30 and r(0x584+7)==32 and r(0x1a9)==62,'Multipart boss must use its native per-part damage and combined HP')
 elseif n==4 then
  assert(r(0x1a9)==62 and r(0x60a0+actor)==0 and r(0x6046)==hits+1,'Hidden native boss hitbox must receive native damage')
 elseif n==5 or n==6 then
  assert(r(0x1a9)==64 and r(0x6046)==hits and r(0x6020)==1,'Native and custom pickups must be immune to fireballs')
 end
 print('Native damage case '..n..' passed')
 -- The fixture isolates the damage handler from an uninitialized boss AI.
 w(0x434+actor,0);w(0x434+7,0);w(0x60a0+actor,0);w(0x6020,0)
 if n==6 then emu.stop(0) end
end,emu.callbackType.exec,0xe8f0)
emu.addEventCallback(function() frame=frame+1;if frame==800 then print('FAIL missing damage fixture');emu.stop(1) end end,emu.eventType.endFrame)
