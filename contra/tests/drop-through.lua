local f=0
local p=PLAYER or 0
local phase=PHASE or 0
local mode=MODE or 'platform'
local upper=84-phase
local minY=255
local maxY=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for i=0,1 do
  setPad(i,{start=i==0 and (f==120 or f==200 or f==400),select=i==0 and f==180,
   down=i==p and f>=950,a=i==p and (f>=1000 and f<1070 or f>=1100 and f<1105)})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 w(N.VERTICAL_SCROLL,phase)
 for i=0,127 do
  local row=math.floor((i%64)/4)
  local value=0
  if row==6 then value=mode=='solid' and 0xFF or 0x55 end
  if mode=='blocked' and row==7 then value=0xFF end
  if mode~='no-lower' and (row==9 or row==12) then value=0x55 end
  w(N.BG_COLLISION_DATA+i,value)
 end
 for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end
 for i=0,1 do
  local b=0x6000+i*128
  w(b+4,POWER or 0);w(b+0x35,0);w(b+0x4C,2)
  if f<945 then
   w(N.SPRITE_Y_POS+i,upper);w(N.SPRITE_X_POS+i,80+i*80);w(N.PLAYER_HIDDEN+i,0)
   w(b+5,0);w(b+0x18,0);w(b+0x19,0);w(b+0x17,0);w(b+6,0);w(b+7,0)
  end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f==480 and STAGE then w(N.CURRENT_LEVEL,STAGE);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f>=1000 then
  local y=r(N.SPRITE_Y_POS+p);minY=math.min(minY,y);maxY=math.max(maxY,y)
  assert(r(N.SPRITE_Y_POS+1-p)==upper,'The other controller must remain on its own platform')
  assert(r(N.PLAYER_STATE+p)==1,'Dropping must preserve the player')
 end
 if f==1080 then
  local y=r(N.SPRITE_Y_POS+p)
  if mode=='platform' then
   assert(y==132-phase and minY>=upper,'Down+A must descend directly and stop on the next platform while A stays held')
  elseif mode=='solid' then
   assert(maxY<=upper and minY<upper-16,'Solid terrain must keep its normal crouch-jump collision')
  else
   assert(y==upper and minY==upper and maxY==upper,'Horizontal platforms must retain the native no-pit drop guard')
  end
 end
 if f==1180 then
  if mode=='platform' then assert(r(N.SPRITE_Y_POS+p)==180-phase,'A second fresh Down+A must drop exactly one more platform') end
  print('Drop player='..p..' power='..(POWER or 0)..' phase='..phase..' mode='..mode..' y='..r(N.SPRITE_Y_POS+p))
  emu.stop(0)
 end
end,emu.eventType.endFrame)
