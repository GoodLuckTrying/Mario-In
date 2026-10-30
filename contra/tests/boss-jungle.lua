-- Use three-frame B taps; single-frame taps can fall between native updates.
-- Load the real boss approach, terrain, actors, HP and destruction sequence.
-- The approach fixture crosses its pit; combat itself uses controller input.
local f=0
local p=PLAYER or 0
local coop=p==1
local warped=false
local ready=false
local core=false
local turrets={}
local hits={}
local custom=0
local finished=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for i=0,1 do
  setPad(i,{start=i==0 and (f==120 or f==200 or f==400),select=coop and i==0 and f==180,
   right=f>=740 and not ready and (i==p or coop),
   b=f>=740 and (not ready and (i==p or coop) or i==p and f%8<3 and (turrets[0] and turrets[1] or r(N.SPRITE_Y_POS+p)<148)),
   a=ready and i==p and f%90<26})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not warped and r(N.GAME_ROUTINE_INDEX)==5 and r(N.CURRENT_LEVEL)==0 then
  w(N.LEVEL_SCREEN_NUMBER,10);warped=true
 end
end,emu.callbackType.exec,N.load_current_supertiles_screen_indexes)
emu.addMemoryCallback(function()
 if f<730 or r(N.CURRENT_LEVEL)~=0 then return end
 for i=0,coop and 1 or 0 do
  if r(N.LEVEL_SCREEN_NUMBER)<11 then
   w(N.SPRITE_Y_POS+i,100);w(0x6005+i*128,0);w(0x6018+i*128,0);w(0x6019+i*128,0);w(0x6017+i*128,0)
  end
  w(0x6004+i*128,i==p and (POWER or 2) or 0);w(0x6035+i*128,0);w(0x604C+i*128,2);w(0x6049+i*128,255)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if FIRE_ONLY then
  local i=emu.getState()['cpu.x']
  w(N.CONTROLLER_STATE+i,r(N.CONTROLLER_STATE+i)&0xBF)
  w(N.CONTROLLER_STATE_DIFF+i,r(N.CONTROLLER_STATE_DIFF+i)&0xBF)
 end
end,emu.callbackType.exec,N.check_player_fire)
emu.addMemoryCallback(function()
 local e=r(N.ENEMY_CURRENT_SLOT);local kind=r(N.ENEMY_TYPE+e)
 if kind~=0x10 and kind~=0x11 then return end
 local owner=emu.getState()['cpu.a']
 assert(owner==p,'Boss damage must credit the firing controller')
 if kind==0x10 then turrets[r(N.ENEMY_ATTRIBUTES+e)]=true end
 hits[kind]=(hits[kind] or 0)+1
 local sp=emu.getState()['cpu.sp']
 local caller=r(0x100+(sp+1)%256)+r(0x100+(sp+2)%256)*256+1
 if H.FireEnemies and caller>=H.FireEnemies and caller<H.Stomps then custom=custom+1 end
end,emu.callbackType.exec,N.bullet_collision_logic)
emu.addEventCallback(function()
 if finished then return end
 f=f+1
 ready=ready or f>740 and r(N.LEVEL_SCREEN_NUMBER)>=11 and r(N.LEVEL_STOP_SCROLL)==255 and r(N.BOSS_AUTO_SCROLL_COMPLETE)~=0
 if TRACE and f%500==0 then print('f '..f..' screen '..r(N.LEVEL_SCREEN_NUMBER)..' ready '..tostring(ready)..' power '..r(0x6004+p*128)..' pos '..r(N.SPRITE_X_POS+p)..'/'..r(N.SPRITE_Y_POS+p)..' hidden '..r(N.PLAYER_HIDDEN+p)..' routine '..r(N.LEVEL_ROUTINE_INDEX)..' flag '..r(N.BOSS_DEFEATED_FLAG)..' fire '..r(0x6180+p)..'/'..r(0x6182+p)) end
 if r(N.CURRENT_LEVEL)==0 and r(N.BOSS_DEFEATED_FLAG)~=0 then core=true end
 if r(N.CURRENT_LEVEL)==1 or f==7500 then
  finished=true
  print('Jungle boss player='..p..' fire-only='..tostring(FIRE_ONLY)..' hits core='..(hits[0x11] or 0)..' turrets='..(hits[0x10] or 0)..' fireballs='..custom..' defeated='..tostring(core)..' next-stage='..r(N.CURRENT_LEVEL))
  assert(ready and core,'Controller-fired projectiles must defeat the actual first boss core')
  assert(turrets[0] and turrets[1],'Both native boss turrets must accept projectile hits')
  if FIRE_ONLY then assert(custom>=34,'Fireballs alone must damage both turrets and defeat the full-health core') end
  assert(r(N.CURRENT_LEVEL)==1,'Native boss defeat must open the tunnel and advance into Base 1')
  local o=assert(io.open(TEST_ROOT..'/build/boss-clear-'..p..'-'..tostring(FIRE_ONLY)..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
