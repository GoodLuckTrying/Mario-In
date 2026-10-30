-- Real shared weapon pickups and B input, with independent SMB fireballs.
local f=0
local p=PLAYER or 0
local b=0x6000+p*128
local weapon=WEAPON or 0
local power=POWER or 0
local stage=STAGE or 0
local gun=false
local fire=false
local together=false
local held=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for i=0,1 do
  setPad(i,{start=i==0 and (f==120 or f==200 or f==400),select=i==0 and f==180,
   b=i==p and (f==1000 or f==1006 or f==1012 or f>=1020 and f<1100)})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for a=0x680,0x6FF do w(a,0x55) end
 for i=0,1 do
  local base=0x6000+i*128
  w(base+0x4C,2);w(N.NEW_LIFE_INVINCIBILITY_TIMER+i,200)
  if f<945 then
   w(base+4,i==p and power or 0);w(base+0x35,0)
   w(N.SPRITE_X_POS+i,80+i*80);w(N.SPRITE_Y_POS+i,164)
   w(base+5,0);w(base+0x18,0);w(base+0x19,0);w(base+0x17,0)
   w(N.P1_CURRENT_WEAPON+i,0)
  end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f==480 and stage~=0 then w(N.CURRENT_LEVEL,stage);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f==960 then
  for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0) end
  local e=15
  for a=0x4B8+e,0x5E8+e,16 do w(a,0) end
  w(N.ENEMY_ROUTINE+e,3);w(N.ENEMY_TYPE+e,0);w(N.ENEMY_HP+e,0xF0)
  w(N.ENEMY_STATE_WIDTH+e,0x80);w(N.ENEMY_SCORE_COLLISION+e,0x22)
  w(N.ENEMY_ATTRIBUTES+e,weapon)
  w(N.ENEMY_X_POS+e,r(N.SPRITE_X_POS+p));w(N.ENEMY_Y_POS+e,r(N.SPRITE_Y_POS+p))
 end
 if f==980 then
  assert((r(N.P1_CURRENT_WEAPON+p)&0xF)==weapon,'A native pickup must equip its actual Contra weapon')
  if weapon==0 then assert((r(N.P1_CURRENT_WEAPON+p)&0x10)~=0,'R pickups must enable rapid fire') end
  assert(r(b+4)==power,'Weapon pickups must preserve Mario size and Fire Flower power')
  assert(r(N.P1_CURRENT_WEAPON+1-p)==0,'The other player must keep their own gun')
 end
 if f>1000 and f<1100 then
  local guns=0;local fires=0
  for s=0,15 do
   if r(N.PLAYER_BULLET_SLOT+s)~=0 and r(N.PLAYER_BULLET_OWNER+s)==p then
    assert((r(N.PLAYER_BULLET_SLOT+s)&0xF)==weapon+1,'Each gun must use its native projectile type')
    guns=guns+1;gun=true
    if f>=1040 then held=true end
   end
  end
  for s=0,3 do
   if r(0x6180+s)~=0 and r(0x61C0+s)==p then fires=fires+1;fire=true end
  end
  assert(fires<=2,'Gun projectiles must not use or overwrite Mario fireball slots')
  if power~=2 then assert(fires==0,'Small/Super characters get guns while fireballs require Fire form') end
  if guns>0 and fires>0 then together=true end
 end
 if f==1120 then
  print('Weapons player='..p..' stage='..stage..' weapon='..weapon..' power='..power..' gun='..tostring(gun)..' fire='..tostring(fire)..' together='..tostring(together))
  assert(gun,'Every form must fire its equipped Contra weapon with B')
  if power==2 then assert(fire and together,'B in Fire form must shoot both independent weapons') end
  if weapon==1 or weapon==4 then assert(held,'Machine gun and laser must retain their native held-B behavior') end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
