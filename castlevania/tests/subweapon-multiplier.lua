-- Native II/III pickup contact followed by real Up+B controller edges.
local frame=0;local pending=nil;local n=0;local shots=0
local cases={}
for _,weapon in ipairs({8,9,11,13}) do for multiplier=0,2 do cases[#cases+1]={weapon=weapon,multiplier=multiplier,start=700+#cases*100} end end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function current() for _,c in ipairs(cases) do if frame>=c.start and frame<c.start+100 then return c end end end
emu.addEventCallback(function() local c=current();emu.setInput({start=frame==120,up=c and (frame==c.start+3 or frame==c.start+67 or frame==c.start+84),b=c and (frame==c.start+3 or frame==c.start+67 or frame==c.start+84)},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local c=current();if not c then return end
 if frame==c.start then
  n=n+1;shots=0
  for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
  w(0x6001,2);w(0x600d,90);w(0x45,64);w(0x5b,0);w(0x46c,0);w(0x434,0);w(0x47,0);w(0x3f,176);w(0x354,176)
  w(0x15b,c.weapon);w(0x15c,0);w(0x15d,0);w(0x71,30);w(0x64,0);w(0x603e,0);w(0x6020,0);w(0x6021,0)
  if c.multiplier>0 then
   local actor=19
   for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530,0x4dc}) do w(base+actor,0) end
   w(0x434+actor,0x2f);w(0x584+actor,0x0c);w(0x4c0+actor,c.multiplier==1 and 0x2f or 0x30);w(0x31c+actor,c.multiplier==1 and 0x52 or 0x53)
   w(0x38c+actor,r(0x38c));w(0x354+actor,184)
  end
 end
 if frame==c.start+66 or frame==c.start+83 then
  w(0x434,0);w(0x46c,0);w(0x15c,0);w(0x71,30)
  for x=20,22 do w(0x434+x,0) end
  local occupied=c.multiplier+(frame==c.start+83 and 1 or 0)
  for x=20,19+occupied do
   w(0x434+x,0x17);w(0x584+x,3);w(0x46c+x,2);w(0x4dc+x,255);w(0x4f8+x,0);w(0x354+x,120);w(0x38c+x,128)
  end
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1;local c=current();if not c then return end
 if frame==c.start+1 then assert(r(0x15b)==c.weapon and r(0x64)==c.multiplier,'II/III pickup must retain equipped weapon and native multiplier') end
 if frame>c.start+5 then for x=20,22 do if r(0x434+x)==0x17 then shots=shots+1 end end end
 if frame==c.start+60 then
  assert(shots>0 and r(0x71)==29,'Up+B must still throw after multiplier '..c.multiplier..' weapon '..c.weapon..' hearts '..r(0x71)..' shots '..shots)
  assert(r(0x6020)==0 and r(0x6021)==0,'Up+B must not add Mario fireballs')
  print('Multiplier case '..n..' weapon '..c.weapon..' II/III '..c.multiplier..' passed')

 end
 if frame==c.start+68 then assert(r(0x71)==29,'Multiplier must allow its last free projectile slot: weapon '..c.weapon..' multiplier '..c.multiplier) end
 if frame==c.start+85 then assert(r(0x71)==30,'Full native capacity must reject a shot without spending hearts: weapon '..c.weapon..' multiplier '..c.multiplier) end
 if frame==c.start+95 then print('Native capacity '..c.weapon..' multiplier '..c.multiplier..' passed');if n==#cases then print('Subweapon multipliers passed: '..#cases..' pickups/throws and 24 capacity checks');emu.stop(0) end end
 assert(frame<2000,'Multiplier fixture timeout')
end,emu.eventType.endFrame)
