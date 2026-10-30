-- Native enemy damage at both sides of the final-quarter threshold.
local frame=0;local pending=nil;local count=0
local cases={}
for power=0,2 do for _,hp in ipairs({64,25,24,17,16,8,4}) do cases[#cases+1]={power=power,hp=hp,start=700+#cases*25} end end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for _,c in ipairs(cases) do if frame==c.start then
  pending=c
  for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
  local actor=19
  for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530,0x4dc}) do w(base+actor,0) end
  w(0x28,0);w(0x6001,c.power);w(0x600d,0);w(0x5b,0);w(0x45,c.hp);w(0x44,c.hp);w(0x46c,0);w(0x3f,176);w(0x354,176);w(0x47,0);w(0x6013,0)
  w(0x603e,0);w(0x6020,0);w(0x6021,0)
  w(0x434+actor,1);w(0x38c+actor,r(0x38c));w(0x354+actor,184);w(0x31c+actor,0x50)
 end end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if not pending then return end
 local c=pending;pending=nil;local expected=math.max(0,c.hp-8)
 assert(r(0x45)==expected,'Low-health policy must preserve native damage')
 assert(r(0x6001)==(expected<=16 and 0 or c.power),'Shrink only at low HP: before '..c.hp..' after '..r(0x45)..' power '..c.power)
 assert(r(0x600d)>0 and r(0x5b)>0,'Every hit must still grant invincibility')
 count=count+1;print('Low-health case '..count..' passed')
 -- The native respawn test covers lethal progression; isolate this threshold.
 w(0x434+19,0);w(0x45,64);w(0x44,64);w(0x46c,0);w(0x600d,90)
 if count==#cases then print('Low-health damage passed: '..count..' cases; threshold 16/64 HP');emu.stop(0) end
end,emu.callbackType.exec,0xcf1c)
emu.addEventCallback(function() frame=frame+1;assert(frame<1350,'Low-health fixture timeout') end,emu.eventType.endFrame)
