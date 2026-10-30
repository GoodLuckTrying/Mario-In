AREA=1
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local collected=0
local fired=0
emu.addMemoryCallback(function()if seeded then collected=collected+1 end end,emu.callbackType.exec,H.EnemyBehavior_PickUpMushroom)
emu.addMemoryCallback(function()if seeded then fired=fired+1 end end,emu.callbackType.exec,H.MarioFireSpawn_Create)
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 w(H.PlayerHealth,15);w(H.PlayerMaxHealth,0);w(H.PlayerCurrentSize,1);w(H.PlayerState,0);w(H.PlayerDucking,0);w(H.PlayerXVelocity,0)
 w(H.EnemyState,1);w(H.ObjectType,0x3f);w(H.EnemyRawDataOffset,255);w(H.EnemyArray_46E,0);w(H.EnemyArray_492,4);w(H.ObjectHitbox,3)
 w(H.ObjectXLo,r(H.PlayerXLo));w(H.ObjectXHi,r(H.PlayerXHi));w(H.ObjectYLo,(r(H.PlayerYLo)+29)&255);w(H.ObjectYHi,r(H.PlayerYHi))
 for _,a in ipairs({H.ObjectXVelocity,H.ObjectYVelocity,H.ObjectProjectileTimer,H.ObjectBeingCarriedTimer,H.ObjectStunTimer,H.ObjectFlashTimer,H.EnemyVariable})do w(a,0)end
 -- Isolate native consumption from the already covered object-lift path.
 w(H.HoldingItem,1);w(H.ObjectBeingCarriedIndex,0);w(H.ObjectBeingCarriedTimer,1)
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)return{b=seeded and (f-seeded)%20==2}end
function tick(t)
 if not seeded then return end
 if collected>0 and r(H.PlayerCurrentSize)==0 and r(H.PlayerState)==0 and fired>0 then
  assert(r(H.PlayerMaxHealth)==1 and r(H.PlayerHealth)==47,'native mushroom adds a heart container and fully heals')
  assert(r(H.HoldingItem)==0,'collected mushroom is consumed by its native handler')
  screenshot('mushroom-'..(CHAR or 0));finish('native mushroom pickup, extra heart, healing, SMB growth and restored fireballs')
 end
 assert(f-seeded<350,'mushroom native pickup completes: collected '..collected..' fired '..fired..' holding '..r(H.HoldingItem)..' state '..r(H.PlayerState)..' health '..r(H.PlayerHealth)..' object '..r(H.EnemyState)..' timer '..r(H.ObjectBeingCarriedTimer))
end
