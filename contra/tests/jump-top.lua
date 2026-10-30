local f=0
local above=false
local returned=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,right=f>=950 and f<1020,b=f>=950,a=f>=980 and f<1005})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for a=0x680,0x6FF do w(a,0x55) end
 for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end
 w(0x6004,POWER or 1);w(0x604C,2);w(N.NEW_LIFE_INVINCIBILITY_TIMER,0)
 if f<945 then w(N.SPRITE_Y_POS,20);w(0x6005,0);w(0x6018,0) end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f>950 then
  if r(N.PLAYER_HIDDEN)==255 then above=true end
  if above and r(N.PLAYER_HIDDEN)==0 then returned=true end
  assert(r(N.PLAYER_STATE)==1,'Jumping above the screen must not count as falling into a pit')
 end
 if f==1100 then
  print('Above-screen jump: left='..tostring(above)..' returned='..tostring(returned))
  assert(above and returned,'The high-platform jump must leave and re-enter the screen safely')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
