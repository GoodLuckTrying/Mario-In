dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local dead=false
local question=nil
local resumed=nil
emu.addMemoryCallback(function()
 if not first or f-first<10 or seeded then return end
 seeded=f
 for i=1,12 do w(H.ObjType+i,0);w(H.ObjMetastate+i,0)end
 w(H.HeartValues,0);w(H.HeartPartial,1);w(H.ObjInvincibilityTimer,0)
 local i=1
 w(H.ObjType+i,8);w(H.ObjX+i,r(H.ObjX));w(H.ObjY+i,r(H.ObjY));w(H.ObjDir+i,2)
 w(H.ObjHP+i,16);w(H.ObjAttr+i,0);w(H.ObjUninitialized+i,0);w(H.ObjInvincibilityMask+i,0);w(H.ObjInvincibilityTimer+i,0)
 w(H.ObjAnimCounter+i,6);w(H.ObjState+i,0);w(H.ObjQSpeedFrac+i,0x20)
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)
 if r(H.GameMode)==8 then question=question or f;return{start=f-question==10}end
 return{a=seeded and f-seeded<5}
end
function tick(t)
 if not seeded then return end
 if r(H.GameMode)==17 then dead=true end
 if dead and question and r(H.GameMode)==5 and r(H.IsUpdatingMode)==1 then resumed=resumed or f end
 if resumed and f-resumed==10 then
  assert(r(H.HeartValues)&15==2,'Continue restores three native hearts')
  assert(r(0x7fc0)==0 and r(0x7fc1)==0,'death and continue discard old fireballs')
  finish('real contact damage, native death animation, continue screen and restored health')
 end
 assert(t<2000,'complete native death/continue sequence: mode '..r(H.GameMode)..' sub '..r(H.GameSubmode))
end
