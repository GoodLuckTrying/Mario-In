local frame=0
local ids={8,9,11,13,15}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local seen=false
emu.addEventCallback(function() local phase=(frame-700)%80;emu.setInput({start=frame==120,up=frame>=700 and phase==1,b=frame>=700 and phase==1},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 local n=math.floor((frame-700)/80)+1;local phase=(frame-700)%80
 if n<1 or n>5 then return end
 if phase==0 then
  w(0x6001,2);w(0x15b,ids[n]);w(0x15c,0);w(0x71,30);w(0x64,0);w(0x434,0);w(0x46c,0);w(0x600d,90)
  for x=20,22 do w(0x434+x,0) end
  seen=false
 end
 if phase>2 then for x=20,22 do if r(0x434+x)~=0 then seen=true end end end
 if phase==50 then
  local cost=ids[n]==15 and 5 or 1
  if not seen or r(0x71)~=30-cost or r(0x6020)~=0 or r(0x6021)~=0 then print('FAIL weapon '..ids[n]..' hearts '..r(0x71)..' projectile '..tostring(seen));emu.stop(1);return end
  print('Native subweapon '..ids[n]..' passed')
  if n==5 then emu.stop(0) end
 end
end,emu.eventType.endFrame)
