-- Isolated native animation holds, enemy damage and friendly projectiles.
local frame=0;local pending=nil;local number=0;local count=0
local cases={}
if not COMBAT_FRIENDLY_ONLY then for _,ai in ipairs({8,12,14}) do for _,method in ipairs({'whip','fire','stomp'}) do for _,hold in ipairs({128,255}) do cases[#cases+1]={ai=ai,method=method,hold=hold,start=700+#cases*25} end end end end
for _,method in ipairs({'whip','fire'}) do for slot=20,22 do cases[#cases+1]={ai=23,method=method,hold=0,slot=slot,start=700+#cases*25} end end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for _,c in ipairs(cases) do if frame==c.start then
  pending=c;number=number+1
  for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
  local actor=c.slot or 8
  for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530,0x514,0x4dc}) do w(base+actor,0) end
  w(0x434+actor,c.ai);w(0x488+actor,c.hold);w(0x31c+actor,0x3d)
  w(0x6001,2);w(0x600d,0);w(0x5b,0);w(0x45,64);w(0x46c,0);w(0x3f,176);w(0x354,176);w(0x38c,128);w(0x40,128);w(0x41,0);w(0x450,0)
  w(0x6020,0);w(0x6021,0);w(0x603e,0);w(0x6039,0)
  if c.method=='whip' then
   w(0x603e,13);w(0x38c+actor,148);w(0x354+actor,172);count=r(0x603f)
  elseif c.method=='fire' then
   w(0x38c+actor,120);w(0x354+actor,124);count=r(0x6046)
   w(0x6020,1);w(0x6022,116);w(0x6024,120);w(0x6026,0);w(0x6050,0);w(0x6028,0);w(0x602a,0);w(0x602c,50)
  else
   local top=160-r(0xe46b+c.ai*2)
   w(0x38c+actor,128);w(0x354+actor,160);w(0x46c,1);w(0x3f,top-15);w(0x354,top-15);w(0x6008,top-18);w(0x6005,2);w(0x6004,0);count=r(0x6045)
  end
 end end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if not pending then return end
 local c=pending;pending=nil;local actor=c.slot or 8
 local counter=c.method=='whip' and 0x603f or c.method=='fire' and 0x6046 or 0x6045
 if c.slot then
  assert(r(0x434+actor)==23 and r(counter)==count,'Mario attacks must preserve friendly native weapon slot '..actor..' method '..c.method)
 else
  assert(r(counter)==count+1,'Frozen enemy animation must not block '..c.method..' AI '..c.ai..' hold '..c.hold)
  if c.ai==8 or c.ai==14 then assert(r(0x584+actor)==32,'Native multi-hit enemy must accumulate original damage')
  else assert(r(0x434+actor)>=0x28,'Native enemy death handler must run') end
  if c.method=='stomp' then assert(r(0x6005)==252 and r(0x45)==64,'Stomp must bounce without damage') end
 end
 print('Combat animation case '..number..' passed')
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 w(0x6020,0);w(0x603e,0);w(0x6039,0);w(0x46c,0)
 if number==#cases then print('Combat animation passed: '..#cases..' cases');emu.stop(0) end
end,emu.callbackType.exec,0xe8f0)
emu.addEventCallback(function() frame=frame+1;assert(frame<1400,'Combat animation fixture timeout') end,emu.eventType.endFrame)
