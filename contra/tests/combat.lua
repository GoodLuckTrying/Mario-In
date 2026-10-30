local f=0
local p=PLAYER or 0
local power=POWER or 2
local mode=MODE or 'stomp'
local base=0x6000+p*128
local pending=false
local hit=false
local secondHit=false
local initialLives=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local slot=r(N.ENEMY_CURRENT_SLOT)
 if PAIR and hit and not secondHit and slot==14 then
  secondHit=true
  w(N.ENEMY_TYPE+14,5);w(N.ENEMY_HP+14,1)
  w(N.ENEMY_SCORE_COLLISION+14,0x30);w(N.ENEMY_STATE_WIDTH+14,2)
  w(N.ENEMY_X_POS+14,r(N.SPRITE_X_POS+p)+8);w(N.ENEMY_Y_POS+14,128)
  return
 end
 if not pending or slot~=15 then return end
 pending=false;hit=true
 w(base+4,power);w(base+0x35,0);w(N.P1_CURRENT_WEAPON+p,3)
 w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0);w(N.INVINCIBILITY_TIMER+p,0)
 w(N.ENEMY_X_POS+15,r(N.SPRITE_X_POS+p));w(N.ENEMY_Y_POS+15,100)
 w(N.SPRITE_Y_POS+p,100)
 if mode=='stomp' or mode=='capsule' then
  w(N.ENEMY_TYPE+15,mode=='capsule' and 3 or 5);w(N.ENEMY_HP+15,1)
  w(N.ENEMY_SCORE_COLLISION+15,0x30);w(N.ENEMY_STATE_WIDTH+15,mode=='capsule' and 0xB or 2)
  w(N.ENEMY_Y_POS+15,128)
  w(base+5,2);w(base+0x18,2);w(base+0x2F,98)
 elseif mode=='bullet' or mode=='mortar' then
  if mode=='mortar' then w(N.ENEMY_TYPE+15,0xB);w(N.ENEMY_HP+15,1) end
  -- Descending onto a bullet must cause damage rather than a stomp.
  w(base+5,2);w(base+0x18,2);w(base+0x2F,70)
 else
  w(base+5,0);w(base+0x18,0)
  if mode=='overhead' then w(N.ENEMY_Y_POS+15,88) end
 end
end,emu.callbackType.exec,H.Stomps)
emu.addEventCallback(function()
 f=f+1
 if f==800 then
  initialLives=r(N.P1_NUM_LIVES+p)
  for slot=PAIR and 14 or 15,15 do
   for a=0x4B8+slot,0x5E8+slot,16 do w(a,0) end
   w(N.ENEMY_ROUTINE+slot,2);w(N.ENEMY_TYPE+slot,1)
   w(N.ENEMY_X_POS+slot,r(N.SPRITE_X_POS+p));w(N.ENEMY_Y_POS+slot,100)
   w(N.ENEMY_SCORE_COLLISION+slot,1);w(N.ENEMY_STATE_WIDTH+slot,0)
  end
  pending=true
 end
 if f==803 then
  assert(hit,'Exercise the native enemy collision dispatcher')
  if mode=='stomp' then
   print('stomp HP='..r(N.ENEMY_HP+15)..' state='..r(N.ENEMY_ROUTINE+15)..' player='..r(N.PLAYER_STATE+p)..' vy='..r(base+0x18))
   assert(r(N.ENEMY_HP+15)==0,'Stomps must kill a normal soldier through its native death routine')
   assert(r(N.PLAYER_STATE+p)==1 and r(base+0x18)>=128,'The stomping player must bounce alive')
   if PAIR then assert(secondHit and r(N.ENEMY_HP+14)==0,'Both neighboring enemies must be stomped in the same frame') end
  elseif mode=='capsule' then
   assert(r(N.ENEMY_TYPE+15)==0,'Stomping a capsule must release its native power-up')
   assert(r(N.PLAYER_STATE+p)==1 and r(base+0x18)>=128,'Capsule stomps must bounce alive')
  elseif mode=='overhead' and power==0 then
   assert(r(N.PLAYER_STATE+p)==1 and r(base+4)==0,'A bullet above Small Mario must miss his actual body')
  elseif power>0 then
   assert(r(base+4)==0 and r(N.PLAYER_STATE+p)==1,'Contact must shrink Super/Fire without killing the player')
   assert(r(N.P1_CURRENT_WEAPON+p)==3,'Shrinking must preserve the equipped Contra gun')
   assert(r(N.NEW_LIFE_INVINCIBILITY_TIMER+p)>0,'Shrinking grants temporary invulnerability')
  else
   assert(r(N.PLAYER_STATE+p)==2,'Small form must die on enemy bullet contact')
  end
 end
 if f==850 and not RETRY then
  if power>0 and mode~='stomp' and mode~='capsule' then
   assert(r(base+4)==0 and r(base+0x1E)==0,'Small form and collision height must persist after the transformation')
  end
  print('PASS combat '..mode..' player '..p..' power '..power);emu.stop(0)
 end
 if RETRY and f==1200 then
  print('Retry player '..p..' lives '..initialLives..' -> '..r(N.P1_NUM_LIVES+p)..' supplies '..r(base+0x4C))
  assert(r(N.P1_NUM_LIVES+p)==initialLives-1 and r(N.PLAYER_STATE+p)==1,'Small death must consume one life and respawn')
  assert(r(base+4)==0 and r(base+0x4C)==2,'Every new life must start small and receive two new supplies')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
