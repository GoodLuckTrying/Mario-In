local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local spent=0; local projectile=false; local doorMoved=false
emu.addEventCallback(function() emu.setInput({start=frame==120,up=frame>=701 and frame<703,b=frame==701},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then w(0x6001,2);w(0x15b,8);w(0x71,20);w(0x64,0);w(0x434,0);w(0x46c,0) end
 if frame>=703 and frame<760 then
  if r(0x71)<20 then spent=20-r(0x71) end
  for x=20,22 do if r(0x434+x)~=0 then projectile=true end end
 end
 if frame==760 then
  if spent~=1 or not projectile or r(0x6020)~=0 or r(0x6021)~=0 then print('Subweapon failed '..spent..' '..tostring(projectile));emu.stop(1);return end
  print('Up+B dagger passed: native projectile, one heart, no fireball')
  w(0x18,8);w(0x19,0);w(0x28,1);w(0x2e,128);w(0x584,1);w(0x38c,170);w(0x40,170);w(0x41,0);w(0x3d,0);w(0x3e,1)
  w(0x60a3,3);w(0x60c3,100);w(0x6020,1)
 end
 if frame>760 and r(0x19)~=2 then doorMoved=true end
 if frame==780 or frame==800 or frame==840 or frame==880 then
 local f=io.open((TEST_ROOT..'/analysis/door-')..frame..'.png','wb');f:write(emu.takeScreenshot());f:close()
 end
 if frame%40==0 and frame>760 then print("door mode="..r(0x18).." phase="..r(0x19).." x="..r(0x38c).." stage="..r(0x28)) end
 if frame==1200 then
  if not doorMoved or r(0x18)~=5 or r(0x28)~=2 then print('Door scripted walk failed x='..r(0x38c));emu.stop(1);return end
  print('Door scripted walk reached target despite stale pickup/fireball state');emu.stop(0)
 end
end,emu.eventType.endFrame)
