-- A background boss's mouth is not a soldier-sized stomp surface.
local f=0
local done=false
local p=PLAYER or 0
local mode=MODE or 'side'
local b=0x6000+p*128
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=f==120 or f==200 or f==400,select=f==180});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f~=900 or r(N.ENEMY_CURRENT_SLOT)~=15 or done then return end
 done=true
 w(N.ENEMY_TYPE+15,mode=='perspective' and 0x14 or 0x10);w(N.ENEMY_HP+15,15);w(N.ENEMY_SCORE_COLLISION+15,9)
 w(N.ENEMY_X_POS+15,100);w(N.ENEMY_Y_POS+15,128);w(N.ENEMY_STATE_WIDTH+15,1)
 w(N.SPRITE_X_POS+p,100);w(N.SPRITE_Y_POS+p,mode=='top' and 85 or 100)
 w(N.PLAYER_STATE+p,1);w(N.PLAYER_HIDDEN+p,0);w(b+5,2);w(b+0x18,2);w(b+0x2F,mode=='top' and 83 or 98)
end,emu.callbackType.exec,H.Stomps)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(N.CURRENT_LEVEL,mode=='perspective' and 1 or 7);w(N.LEVEL_ROUTINE_INDEX,0)end
 if f==900 then
  for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
  w(N.ENEMY_ROUTINE+15,2);w(N.ENEMY_TYPE+15,1);w(N.ENEMY_SPRITES+15,1);w(N.ENEMY_HP+15,0xF0)
 end
 if f==901 then
  assert(done,'Exercise native actor processing')
  assert(r(N.ENEMY_HP+15)==(mode=='top' and 13 or 15),'Only landing on the real top may injure a boss, and a low-HP boss must still take normal stomp damage')
  if mode=='top' then assert(r(b+0x18)>=128,'A valid boss stomp must bounce')end
  print('PASS boss stomp '..mode..' p'..p..' HP '..r(N.ENEMY_HP+15));emu.stop(0)
 end
end,emu.eventType.endFrame)
