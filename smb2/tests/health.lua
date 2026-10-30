dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local hit=nil
local healed=nil
local stage=0
local nativehits=0
local lives=nil
local function palette(small)
 local colors=(CHAR==3)and{small and 0x30 or 0x37,0x27,0x19}or(small and{0x16,0x27,0x18}or{0x37,0x27,0x16})
 for i=1,3 do assert(emu.read(0x3f10+i,emu.memType.nesPpuDebug)==colors[i],'real health changes select the matching Small/Fire hardware palette')end
end
local function enemy(kind,x,y)
 local i=0
 for _,a in ipairs({H.ObjectTimer1,H.ObjectTimer2,H.ObjectStunTimer,H.ObjectFlashTimer,H.ObjectProjectileTimer,H.ObjectBeingCarriedTimer,H.ObjectXAcceleration,H.ObjectYAcceleration,H.EnemyArray_SpawnsDoor,H.EnemyCollision,H.EnemyVariable,H.ObjectXVelocity,H.ObjectYVelocity})do w(a+i,0)end
 w(H.ObjectType,kind);w(H.ObjectXLo,x);w(H.ObjectXHi,r(H.PlayerXHi));w(H.ObjectYLo,y);w(H.ObjectYHi,r(H.PlayerYHi))
 w(H.EnemyState,1);w(H.EnemyRawDataOffset,255);w(H.EnemyArray_46E,0);w(H.EnemyArray_492,5);w(H.ObjectHitbox,2);w(H.EnemyHP,0)
end
emu.addMemoryCallback(function()if seeded then nativehits=nativehits+1 end end,emu.callbackType.exec,H.DamagePlayer)
emu.addMemoryCallback(function()
 if not first or f-first<130 then return end
 if not seeded then
  seeded=f
  lives=r(H.ExtraLives)
  for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
  w(H.PlayerXLo,120);w(H.PlayerXVelocity,0);w(H.PlayerInAir,0)
  w(H.PlayerHealth,HP or 0x1f);w(H.PlayerMaxHealth,2);w(H.PlayerCurrentSize,(HP or 0x1f)<16 and 1 or 0);w(H.DamageInvulnTime,0)
  enemy(1,130,(r(H.PlayerYLo)+16)&255)
 end
 if stage==1 and hit and f-hit>170 and r(H.PlayerState)==0 then
  enemy(0,r(H.PlayerXLo),(r(H.PlayerYLo)+17)&255);stage=2
 end
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if HP==15 and hit and f-hit>100 then return{a=t%90<4}end
 if stage>=3 then return{b=t%20==0}end
 return{}
end
function tick(t)
 if not seeded then return end
 local before=HP or 0x1f
 if stage==0 and nativehits>0 then
  hit=f;stage=1
  if before==15 then
   assert(r(H.PlayerState)==7,'last-heart hit starts the native death state')
  else
  assert(r(H.PlayerHealth)==before-16,'real enemy contact removes exactly one native heart')
  end
  screenshot('hurt-'..(CHAR or 0)..'-'..before)
 end
 if before==15 then
  if r(H.ExtraLives)==lives-1 and r(H.PlayerState)==0 and r(H.PlayerHealth)==63 then
   assert(r(H.PlayerCurrentSize)==0,'native next life starts big again')
   finish('small-form death, life loss and native big-form retry')
  end
  assert(f-seeded<1400,'native death must finish: lives '..r(H.ExtraLives)..' hp '..r(H.PlayerHealth)..' size '..r(H.PlayerCurrentSize)..' state '..r(H.PlayerState)..' mode '..r(H.GameMode));return
 end
 if stage==1 and hit and f-hit==80 then
  assert(r(H.PlayerHealth)==before-16,'damage grace prevents repeated heart loss')
  assert(r(H.PlayerCurrentSize)==(before==0x1f and 1 or 0),'native last-heart threshold controls shrinking')
  palette(before==0x1f)
  if before>0x1f then finish('native extra hearts retain big Fire form after a hit');return end
 end
 if stage==2 and r(H.PlayerHealth)>=0x1f and r(H.PlayerCurrentSize)==0 and r(H.PlayerState)==0 then healed=f;stage=3 end
 if stage==3 and f-healed>35 then
  local fires=0;for i=0,8 do if r(0x7e40+i)>0 then fires=fires+1 end end
  assert(fires>0,'a real heart restores big form and fireballs')
  palette(false)
  screenshot('healed-'..(CHAR or 0));finish('native hit, shrink, invulnerability, heart healing, growth and restored fireballs')
 end
 assert(f-seeded<600,'native heart interaction finishes; stage '..stage..' hits '..nativehits..' hp '..r(H.PlayerHealth)..' state '..r(H.PlayerState))
end
