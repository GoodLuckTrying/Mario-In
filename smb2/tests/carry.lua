AREA=1
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local carried=nil
local jumped=false
local thrown=false
local shots=0
emu.addMemoryCallback(function()if seeded then shots=shots+1 end end,emu.callbackType.exec,H.MarioFireSpawn_Create)
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0);w(H.PlayerState,0);w(H.PlayerDucking,0);w(H.PlayerXVelocity,0)
 w(H.EnemyState,1);w(H.ObjectType,0x32);w(H.EnemyRawDataOffset,255);w(H.EnemyArray_46E,0);w(H.EnemyArray_492,4);w(H.ObjectHitbox,3)
 w(H.ObjectXLo,r(H.PlayerXLo));w(H.ObjectXHi,r(H.PlayerXHi));w(H.ObjectYLo,(r(H.PlayerYLo)+29)&255);w(H.ObjectYHi,r(H.PlayerYHi))
 for _,a in ipairs({H.ObjectXVelocity,H.ObjectYVelocity,H.ObjectProjectileTimer,H.ObjectBeingCarriedTimer,H.ObjectStunTimer,H.ObjectFlashTimer})do w(a,0)end
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 if not carried then return{b=dt%12==2}end
 local c=f-carried
 return{a=c>=15 and c<35,b=c==45,left=LEFT and c>=36 and c<46,right=not LEFT and c>=36 and c<46}
end
function tick(t)
 if not seeded then return end
 if r(H.HoldingItem)>0 and r(H.PlayerState)==0 and not carried then carried=f end
 if carried then
  if f-carried>17 and r(H.PlayerInAir)>0 then jumped=true end
  if f-carried>45 and r(H.HoldingItem)==0 then thrown=true end
  if f-carried==55 then
   assert(jumped,'Mario jumps while carrying the native vegetable')
   assert(thrown and r(H.ObjectProjectileTimer)>0,'B releases the carried object through the native throw routine')
   assert(shots<=1,'object pickup/throw takes priority over additional fireballs')
   screenshot('carry-'..(CHAR or 0)..'-'..tostring(SMALL)..'-'..tostring(LEFT));finish('native vegetable pickup, carried jump and directional throw')
  end
 end
 assert(f-seeded<250,'native carrying fixture finishes; holding '..r(H.HoldingItem)..' state '..r(H.PlayerState))
end
