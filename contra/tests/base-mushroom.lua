local f=0;local p=PLAYER or 0;local b=0x6000+p*128;local grew=false;local advanced=false;local oldRoom=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 for q=0,1 do setPad(q,{start=q==0 and(f==120 or f==200 or f==400),select=q==0 and f==180,up=q==p and f>=1000 and f<1100,right=q==p and f>=1190 and f<1230})end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for q=0,1 do w(N.NEW_LIFE_INVINCIBILITY_TIMER+q,200)end
 if f==990 then
  oldRoom=r(N.LEVEL_SCREEN_SCROLL_OFFSET)
  w(N.INDOOR_SCREEN_CLEARED,1)
  for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
  for q=0,1 do w(0x6004+q*128,0);w(0x6035+q*128,0);w(0x604c+q*128,2)end
  w(N.SPRITE_X_POS+p,80);w(N.SPRITE_X_POS+1-p,160)
  local e=15
  for a=N.ENEMY_ROUTINE+e,N.ENEMY_ROUTINE+e+19*16,16 do w(a,0)end
  w(N.ENEMY_ROUTINE+e,3);w(N.ENEMY_TYPE+e,0);w(N.ENEMY_HP+e,0xf0)
  w(N.ENEMY_SCORE_COLLISION+e,0x22);w(N.ENEMY_STATE_WIDTH+e,0x80);w(N.ENEMY_ATTRIBUTES+e,0x80)
  w(N.ENEMY_X_POS+e,r(N.SPRITE_X_POS+p));w(N.ENEMY_Y_POS+e,r(N.SPRITE_Y_POS+p))
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(N.CURRENT_LEVEL,STAGE or 1);w(N.LEVEL_ROUTINE_INDEX,0)end
 if f>990 then grew=grew or r(b+4)>0;advanced=advanced or r(N.INDOOR_PLAYER_ADV_FLAG+p)>0 end
 if f>=990 and f%10==0 then print(f..' xy '..r(N.SPRITE_X_POS+p)..','..r(N.SPRITE_Y_POS+p)..' power '..r(b+4)..' morph '..r(b+0x35)..' state '..r(b+5)..' native '..r(N.PLAYER_JUMP_STATUS+p)..' adv '..r(N.INDOOR_PLAYER_ADV_FLAG+p)..' cmd '..r(N.INDOOR_PLAYER_JUMP_FLAG+p)..' pose '..r(0x6112+p))end
 if f==1080 then
  assert(grew and advanced and r(N.INDOOR_PLAYER_ADV_FLAG+p)>0,'exercise the growth/native-script overlap')
  assert(r(b+0x35)==0,'mushroom morph timer must finish during native base advance')
  local pose=r(0x6112+p)
  assert(pose>=128 and pose<=130,'grown player must use moving back-view feet during the room advance')
 end
 if f==1260 then
  assert(grew and advanced and r(N.LEVEL_SCREEN_SCROLL_OFFSET)>oldRoom,'native mushroom pickup followed by real Up room advance')
  assert(r(b+0x35)==0 and r(b+5)==0 and r(N.PLAYER_JUMP_STATUS+p)==0,'room entry returns the grown player to grounded control')
  assert(r(N.PLAYER_STATE+p)==1,'native room advancement preserves the player')
  print('PASS base mushroom/advance p'..p..' stage'..(STAGE or 1));emu.stop(0)
 end
end,emu.eventType.endFrame)
