AREA=1
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil;local samples=0;local standing=0;local poses={};local miny=255;local maxy=0
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 w(H.PlayerXLo,120);w(H.PlayerXHi,0);w(H.PlayerYLo,129);w(H.PlayerYHi,0)
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0)
 w(H.PlayerState,0);w(H.PlayerInAir,1);w(H.PlayerYVelocity,8);w(H.PlayerXVelocity,0)
 w(H.PlayerXAcceleration,0);w(H.PlayerYAcceleration,0)
 for row=0,0xe0,16 do for x=0,15 do w(0x6000+row+x,row>=176 and 0xd5 or 0x40)end end
 w(H.EnemyState,1);w(H.ObjectType,1);w(H.EnemyRawDataOffset,255)
 w(H.ObjectXLo,120);w(H.ObjectXHi,0);w(H.ObjectYLo,160);w(H.ObjectYHi,0)
 w(H.ObjectHitbox,2);w(H.EnemyArray_492,5);w(H.EnemyArray_46E,0)
 for _,a in ipairs({H.ObjectXVelocity,H.ObjectYVelocity,H.ObjectXAcceleration,H.ObjectYAcceleration,H.ObjectNonSticky,H.EnemyCollision,H.ObjectTimer1,H.ObjectTimer2,H.EnemyVariable,H.ObjectProjectileTimer,H.ObjectBeingCarriedTimer,H.ObjectStunTimer,H.ObjectFlashTimer})do w(a,0)end
 if MOVING then w(H.ObjectXVelocity,8)end
 w(H.EnemyMovementDirection,1)
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 if MODE=='jump' then return{a=dt>=50 and dt<65}end
 if MODE=='pickup' then return{b=dt==50}end
 if MODE=='walk' then return{right=dt>=50}end
 return{}
end
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 if TRACE and dt%5==0 then print(string.format('HEAD %d y%d/%d air%d vx%d acc%d vy%d pose%d collision%02X',dt,r(H.PlayerYLo),r(H.ObjectYLo),r(H.PlayerInAir),r(H.PlayerXVelocity),r(H.PlayerXAcceleration),r(H.PlayerYVelocity),r(0x7e15),r(H.EnemyCollision)))end
 if dt>=15 and dt<45 then
  samples=samples+1;if r(H.PlayerInAir)==0 then standing=standing+1 end
  poses[r(0x7e15)]=true;miny=math.min(miny,r(H.PlayerYLo));maxy=math.max(maxy,r(H.PlayerYLo))
 end
 if dt==80 then
  screenshot('enemy-head-'..(MODE or 'stand')..'-'..(CHAR or 0)..'-'..tostring(SMALL))
  assert(standing==samples and samples>=25,'native enemy support persists every frame: '..standing..'/'..samples)
  assert(not poses[4]and not poses[16],'standing on an enemy never selects the airborne pose')
  assert(maxy-miny<=1,'Mario stands at a stable height rather than floating/falling')
  if MODE=='jump' then assert(r(H.PlayerYLo)<miny-15,'A jumps off a supported enemy')end
  if MODE=='pickup' then assert(r(H.HoldingItem)==1,'B picks up the enemy through native lifting')end
  if MODE=='walk' then assert(r(H.PlayerXLo)>130 and r(H.PlayerXVelocity)>=16,'walking off an enemy accelerates normally')end
  finish('stable enemy support, grounded pose and '..(MODE or 'standing'))
 end
end
