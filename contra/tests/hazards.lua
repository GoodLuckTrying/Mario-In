-- Variable-sized fire beams and spiked walls use the same shrink/grace rules.
local f=0
local p=PLAYER or 0
local power=POWER or 2
local b=0x6000+p*128
local mode=MODE or 'flame'
local prepared=false
local hits=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=f==120 or f==200 or f==400,select=f==180});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<900 or prepared or emu.getState()['cpu.x']~=p then return end
 prepared=true
 for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
 for a=N.BG_COLLISION_DATA,N.BG_COLLISION_DATA+127 do w(a,0)end
 w(N.VERTICAL_SCROLL,0);w(N.HORIZONTAL_SCROLL,0)
 w(N.SPRITE_X_POS+p,mode=='flame' and 100 or 144);w(N.SPRITE_Y_POS+p,120);w(N.PLAYER_HIDDEN+p,0)
 w(b+4,power);w(b+0x35,0);w(b+0x4C,2);w(b+0x49,0)
 w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0);w(N.INVINCIBILITY_TIMER+p,0)
 w(N.ENEMY_TYPE+15,0x11);w(N.ENEMY_ROUTINE+15,4);w(N.ENEMY_SPRITES+15,1)
 w(N.ENEMY_HP+15,0xF0);w(N.ENEMY_STATE_WIDTH+15,0);w(N.ENEMY_SCORE_COLLISION+15,0x0F)
 w(N.ENEMY_ATTRIBUTES+15,mode=='flame' and 0x40 or 0xC0);w(N.ENEMY_X_POS+15,144);w(N.ENEMY_Y_POS+15,mode=='flame' and 120 or 170)
 w(N.ENEMY_VAR_1+15,64);w(N.ENEMY_VAR_3+15,0);w(N.ENEMY_VAR_4+15,64);w(N.ENEMY_ANIMATION_DELAY+15,30)
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()if f>=900 then hits=hits+1 end end,emu.callbackType.exec,H.DamageGate)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(N.CURRENT_LEVEL,mode=='flame' and 5 or 6);w(N.LEVEL_ROUTINE_INDEX,0)end
 if f==905 then
  assert(hits>0,'The active hazard must collide with the real player body')
  if power>0 then assert(r(b+4)==0 and r(N.PLAYER_STATE+p)==1 and r(N.NEW_LIFE_INVINCIBILITY_TIMER+p)>0,'A fire beam/spike must shrink a powered character and grant grace')
  else assert(r(N.PLAYER_STATE+p)==2,'A small character must lose a life on hazard contact')end
  print('PASS '..mode..' p'..p..' power'..power..' contacts '..hits);emu.stop(0)
 end
end,emu.eventType.endFrame)
