local f=0
local p=PLAYER or 0
local power=POWER or 0
local mode=MODE or 'valid'
local b=0x6000+p*128
local jingle=0
local hits=0
local armed=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for q=0,1 do
  local code=q==p
  local up=code and mode~='no-up' and f>=1020 and f<1140
  local a=code and ((f>=1050 and f<1056) or (f>=1070 and f<1076))
  local bpress=code and ((f>=1030 and f<1036) or (f>=1090 and f<1096))
  if mode=='held-a' then a=code and f>=1050 and f<1080 end
  if mode=='wrong' then a=code and f>=1030 and f<1036;bpress=code and f>=1050 and f<1056 end
  setPad(q,{start=q==0 and (f==120 or f==200 or f==400 or (mode~='outside' and ((f>=1000 and f<1006) or (f>=1150 and f<1156)))),select=q==0 and f==180,up=up,a=a,b=bpress})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=1150 and emu.getState()['cpu.a']==0x20 then jingle=jingle+1 end
end,emu.callbackType.exec,N.play_sound)
emu.addMemoryCallback(function()
 if armed then hits=hits+1 end
end,emu.callbackType.exec,H.DamageGate)
emu.addMemoryCallback(function()
 if not armed or r(N.ENEMY_CURRENT_SLOT)~=15 then return end
 w(N.ENEMY_X_POS+15,100);w(N.ENEMY_Y_POS+15,100)
 w(N.ENEMY_TYPE+15,5);w(N.ENEMY_HP+15,1);w(N.ENEMY_SCORE_COLLISION+15,0x30);w(N.ENEMY_STATE_WIDTH+15,2)
 w(N.SPRITE_X_POS+p,100);w(N.SPRITE_Y_POS+p,100)
 w(b+5,1);w(b+0x18,0xfd);w(N.PLAYER_JUMP_STATUS+p,1)
 w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0);w(N.INVINCIBILITY_TIMER+p,0)
end,emu.callbackType.exec,H.PlayerBoxGate)
emu.addEventCallback(function()
 f=f+1
 if f==990 then w(b+4,power);w(b+0x35,0);w(b+0x4c,2);for s=0,15 do w(N.ENEMY_ROUTINE+s,0) end end
 if f==1010 and mode~='outside' then assert(r(N.PAUSE_STATE)==1,'Start must pause the game') end
 if f==1120 then
  assert(r(0x6118)==0,'Invincibility must wait for unpausing')
  if mode=='valid' then assert(r(0x6119)==1,'Holding Up with separate B,A,A,B presses must arm the code') end
 end
 if f==1180 then
  assert(r(N.PAUSE_STATE)==0,'Start must unpause')
  assert(r(0x6118)==(mode=='valid' and 1 or 0),'Only the correct paused sequence may enable invincibility')
  assert(jingle==(mode=='valid' and 1 or 0),'The confirmation jingle must play once on activation')
  if mode=='valid' then
   for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end
   w(b+4,power);w(b+0x35,0)
   w(N.ENEMY_ROUTINE+15,3);w(N.ENEMY_SPRITES+15,0x0c);armed=true
  end
 end
 if f==1200 then
  armed=false
  if mode=='valid' then assert(hits>0 and r(b+4)==power and r(N.PLAYER_STATE+p)==1,'Invincibility must preserve both small and powered players on real enemy contact') end
  print('PASS paused cheat '..mode..' player '..p..' form '..power..' damage calls '..hits);emu.stop(0)
 end
end,emu.eventType.endFrame)
