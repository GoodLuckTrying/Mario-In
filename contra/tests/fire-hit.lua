local f=0
local defeated=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,b=f==1000})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=1000 and r(N.ENEMY_CURRENT_SLOT)==15 then defeated=true end
end,emu.callbackType.exec,N.add_enemy_score_set_enemy_routine)
emu.addMemoryCallback(function()
 w(N.CONTROLLER_STATE,r(N.CONTROLLER_STATE)&0xBF);w(N.CONTROLLER_STATE_DIFF,r(N.CONTROLLER_STATE_DIFF)&0xBF)
end,emu.callbackType.exec,N.check_player_fire)
emu.addEventCallback(function()
 f=f+1
 if f==980 then
  w(0x6004,2);w(0x6035,0)
  for a=0x4B8+15,0x5E8+15,16 do w(a,0) end
  w(N.ENEMY_ROUTINE+15,2);w(N.ENEMY_TYPE+15,5);w(N.ENEMY_HP+15,1)
  w(N.ENEMY_STATE_WIDTH+15,2);w(N.ENEMY_SCORE_COLLISION+15,0x30)
  w(N.ENEMY_ANIMATION_DELAY+15,255);w(N.ENEMY_SPRITES+15,0x45)
  w(N.ENEMY_X_POS+15,100);w(N.ENEMY_Y_POS+15,104)
 end
 if f==1060 then
  print('Native fireball soldier defeat='..tostring(defeated))
  assert(defeated,'A real B-fired fireball must kill a native soldier')
  assert(r(N.PLAYER_STATE)==1 and r(0x6004)==2,'Firing must preserve the player')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
