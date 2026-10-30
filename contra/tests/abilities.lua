local f=0
local player=PLAYER or 0
local base=0x6000+player*128
local seeded=false
local contacts=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function seedItem()
 local s=15
 for a=0x4B8+s,0x5E8+s,16 do w(a,0) end
 w(N.ENEMY_ROUTINE+s,3);w(N.ENEMY_TYPE+s,0)
 w(N.ENEMY_HP+s,0xF0);w(N.ENEMY_SCORE_COLLISION+s,0x22)
 w(N.ENEMY_STATE_WIDTH+s,0x80);w(N.ENEMY_ATTRIBUTES+s,0x80)
 w(N.ENEMY_X_POS+s,r(N.SPRITE_X_POS+player));w(N.ENEMY_Y_POS+s,r(N.SPRITE_Y_POS+player))
end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function() contacts=contacts+1 end,emu.callbackType.exec,H.PickupGate)
emu.addEventCallback(function()
 f=f+1
 if f==780 then
  -- Keep the two collectors apart; shared pickups legitimately go to
  -- whichever player the native loop checks first when both touch one.
  for s=0,15 do if r(N.ENEMY_TYPE+s)==0 then w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end end
  w(N.SPRITE_X_POS+player,80);w(N.SPRITE_X_POS+(1-player),160)
 end
 if f==780 or f==830 or f==880 then seedItem() end
 if f==800 then print('power1='..r(base+4)..' contacts='..contacts);assert(r(base+4)==1,'First supplied item must give a mushroom to its collector') end
 if f==850 then assert(r(base+4)==2,'Second supplied item must give a fire flower') end
 if f==900 then
  assert(r(base+4)==2 and contacts==3,'Extra items must preserve Fire form')
  assert(r(0x6004+(1-player)*128)==0,'Other player power must stay independent')
  local o=assert(io.open(TEST_ROOT..'/build/abilities-'..player..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  print('PASS SMB supplies player '..player);emu.stop(0)
 end
end,emu.eventType.endFrame)
