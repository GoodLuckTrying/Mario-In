dofile(TEST_ROOT..'/tests/common.lua')
local menu=nil
emu.addMemoryCallback(function()menu=menu or f end,emu.callbackType.exec,H.MenuGate)
emu.addEventCallback(function()
 if done then return end
 local p1,p2={},{}
 if not first then
  if r(N.gameMode)==2 and r(0x78a1)==0 and menu then
   local t=f-menu
   p1.select=t>=20 and t<=31
   p1.start=t==30
  else p1.start=f%90<4 end
 else
  if input then p1=input(f-first)or{}end
  if input2 then p2=input2(f-first)or{}end
 end
 setPad(0,p1);setPad(1,p2)
end,emu.eventType.inputPolled)
