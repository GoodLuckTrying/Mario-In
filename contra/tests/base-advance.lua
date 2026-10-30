local f=0
local started=false
local screen=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180,up=f>=1000 and f<1010})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 -- Isolate the room-advance mechanic from live soldiers shooting a small
 -- player before the cleared-room fixture is armed. Keep native health,
 -- movement and transition flags intact.
 if f>=500 and f<1015 then
  for p=0,1 do w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,200)end
 end
 if f==480 then w(N.CURRENT_LEVEL,STAGE or 1);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f==990 then
  screen=r(N.LEVEL_SCREEN_SCROLL_OFFSET)
  w(N.INDOOR_SCREEN_CLEARED,1)
  for p=0,1 do w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,200) end
 end
 if f>1000 and r(N.INDOOR_PLAYER_ADV_FLAG)>0 then started=true end
 if f==1100 then
  print('Base advance '..tostring(started)..' room '..screen..' -> '..r(N.LEVEL_SCREEN_SCROLL_OFFSET)..' flag '..r(N.INDOOR_PLAYER_ADV_FLAG)..' location '..r(N.LEVEL_LOCATION_TYPE))
  assert(started and r(N.LEVEL_SCREEN_SCROLL_OFFSET)>screen,'Up must advance both players after clearing a base room')
  assert(r(N.LEVEL_LOCATION_TYPE)==1 and r(N.PLAYER_STATE)==1 and r(N.PLAYER_STATE+1)==1,'Both players must return to normal base control')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
