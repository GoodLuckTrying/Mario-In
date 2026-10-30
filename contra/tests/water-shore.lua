-- A native one-way/solid shore replaces cells in the water's surface row.
-- Walk onto it without A, using real collision lookups and player updates.
local f=0
local p=PLAYER or 0
local power=POWER or 0
local phase=PHASE or 0
local left=LEFT or false
local mode=MODE or 'one-way'
local base=0x6000+p*128
local rise=false
local settled=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function tile(col,row,code)
 local addr=N.BG_COLLISION_DATA+row*4+math.floor(col/4)
 local shift=(3-col%4)*2
 w(addr,(r(addr)&(~(3<<shift)))|(code<<shift))
end
emu.addEventCallback(function()
 local x=r(N.SPRITE_X_POS+p)
 local moving=f>=1000 and not settled
 if mode=='ceiling' or mode=='high-wall' then moving=f>=1000 end
 for i=0,1 do
  setPad(i,{start=i==0 and (f==120 or f==200 or f==400),select=i==0 and f==180,
   right=i==p and moving and not left,left=i==p and moving and left,b=i==p and RUN and moving})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 w(N.VERTICAL_SCROLL,phase);w(N.HORIZONTAL_SCROLL,0);w(N.LEVEL_STOP_SCROLL,255)
 for a=N.BG_COLLISION_DATA,N.BG_COLLISION_DATA+127 do w(a,0) end
 for col=0,15 do tile(col,13,2) end
 for col=left and 2 or 6,left and 9 or 13 do
  tile(col,13,(mode=='solid' or mode=='high-wall') and 3 or 1)
  if mode=='ceiling' or mode=='high-wall' then tile(col,12,3) end
 end
 for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0) end
 for i=0,1 do
  local b=0x6000+i*128
  w(b+0x4C,2);w(N.NEW_LIFE_INVINCIBILITY_TIMER+i,0)
  if f<945 then
   w(b+4,power);w(b+0x35,0);w(b+5,2);w(b+0x18,0);w(b+0x19,0);w(b+0x17,0)
   w(b+6,0);w(b+7,0);w(b+0x16,0);w(b+0x47,1)
   w(N.SPRITE_Y_POS+i,208-phase)
   w(N.SPRITE_X_POS+i,i==p and (mode=='under' and (left and 136 or 120) or left and 192 or 64) or (left and 210 or 32))
  end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f>=950 then
  assert(r(N.PLAYER_STATE+p)==1,'Swimming against the shore must never clip below the map and kill the player')
  assert(r(N.SPRITE_Y_POS+p)<=208-phase,'A platform must not disable buoyancy while feet are inside its surface cell')
  if r(N.SPRITE_Y_POS+p)<208-phase then rise=true end
 end
 if f>=1000 and (left and r(N.SPRITE_X_POS+p)<=128 or not left and r(N.SPRITE_X_POS+p)>=128) then settled=true end
 if f==1180 then
  local x=r(N.SPRITE_X_POS+p);local y=r(N.SPRITE_Y_POS+p)
  print('Shore player='..p..' power='..power..' mode='..mode..' left='..tostring(left)..' run='..tostring(RUN)..' phase='..phase..' xy='..x..'/'..y)
  if mode=='ceiling' or mode=='high-wall' then
   assert(not rise and (left and x>=168 or not left and x<=88),'Water exit must respect low ceilings and banks higher than a native step')
   assert(r(base+0x47)==1,'Blocked swimmers must stay in water')
  else
   assert(rise and settled and x>=(left and 32 or 96) and x<(left and 160 or 224) and y==196-phase,'Walking into shore must lift the feet onto its top without A')
   assert(r(base+5)==0 and r(base+0x47)==0,'The character must finish standing out of water on the platform')
  end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
