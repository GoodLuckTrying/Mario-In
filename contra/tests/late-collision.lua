-- Later-stage solid ledges, cramped corridors, and moving native platforms.
local f=0
local p=PLAYER or 0
local mode=MODE or 'ledge'
local power=POWER or 2
local b=0x6000+p*128
local setup=false
local landed=false
local jumped=false
local startX=nil
local startLives=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local function tile(c,row,code)
 local addr=N.BG_COLLISION_DATA+row*4+math.floor(c/4)
 local shift=(3-c%4)*2
 w(addr,(r(addr)&(~(3<<shift)))|(code<<shift))
end
emu.addEventCallback(function()
 for i=0,1 do setPad(i,{start=i==0 and (f==120 or f==200 or f==400),select=i==0 and f==180,
  right=i==p and f>=1000 and f<1060 and mode~='cart',
  a=i==p and (mode=='cart' and f>=1060 and f<1080 or mode=='ledge' and f>=1000 and f<1035),
  b=i==p and f>=1000 and f<1060})end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 or emu.getState()['cpu.x']~=p then return end
 for e=0,15 do if mode~='cart' or e~=15 then w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end end
 w(N.LEVEL_STOP_SCROLL,255);w(N.VERTICAL_SCROLL,0);w(N.HORIZONTAL_SCROLL,0)
 for a=N.BG_COLLISION_DATA,N.BG_COLLISION_DATA+127 do w(a,0)end
 for c=0,15 do tile(c,mode=='cart' and 13 or 12,3);tile(c,14,3)end
 if mode=='ledge' then for c=7,14 do tile(c,10,3);tile(c,11,3)end end
 if mode=='tunnel' then for c=1,14 do tile(c,10,3)end end
 if setup then return end
 setup=true
 for i=0,1 do
  local q=0x6000+i*128
  w(q+4,power);w(q+5,0);w(q+6,0);w(q+7,0);w(q+0x18,0);w(q+0x19,0);w(q+0x35,0);w(q+0x4C,2)
  w(N.PLAYER_HIDDEN+i,0);w(N.SPRITE_Y_POS+i,180);w(N.SPRITE_X_POS+i,i==p and (mode=='ledge' and 88 or mode=='edge' and 16 or 64) or 50)
  w(N.NEW_LIFE_INVINCIBILITY_TIMER+i,0);w(q+0x49,0)
 end
 if mode=='cart' then
  w(N.SPRITE_Y_POS+p,145);w(N.SPRITE_X_POS+p,112);w(b+5,2);w(b+0x18,2)
  for a=N.ENEMY_ROUTINE+15,N.ENEMY_ROUTINE+15+19*16,16 do w(a,0)end
  w(N.ENEMY_TYPE+15,0x15);w(N.ENEMY_ROUTINE+15,2);w(N.ENEMY_SPRITES+15,0x2A)
  w(N.ENEMY_X_POS+15,112);w(N.ENEMY_Y_POS+15,200)
  w(N.ENEMY_HP+15,0xF0);w(N.ENEMY_STATE_WIDTH+15,0xC0);w(N.ENEMY_SCORE_COLLISION+15,4)
  w(N.ENEMY_X_VELOCITY_FRACT+15,0xC0)
 end
 startX=r(N.SPRITE_X_POS+p);startLives=r(N.P1_NUM_LIVES+p)
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(N.CURRENT_LEVEL,6);w(N.LEVEL_ROUTINE_INDEX,0)end
 if f>=980 and f<1060 and mode=='cart' and r(N.PLAYER_ON_ENEMY+p)>0 then landed=true end
 if f>=1060 and f<1100 and mode=='cart' and r(b+0x18)>=128 then jumped=true end
 if f>=1040 and mode=='ledge' and r(N.SPRITE_X_POS+p)>=116 and r(N.SPRITE_Y_POS+p)==148 then landed=true end
 if f==1060 and mode=='cart' then
  print('Cart x='..r(N.SPRITE_X_POS+p)..' cart='..r(N.ENEMY_X_POS+15)..' y='..r(N.SPRITE_Y_POS+p)..' on='..r(N.PLAYER_ON_ENEMY+p)..' state='..r(b+5))
  assert(landed and r(N.SPRITE_X_POS+p)>startX+10,'Landing on a cart must start it and carry an idle rider')
 end
 if TRACE and f>=990 and f<1100 and f%4==0 then print('f'..f..' x/y='..r(N.SPRITE_X_POS+p)..'/'..r(N.SPRITE_Y_POS+p)..' vy='..r(b+0x18)..' speed='..r(b+6)..' state='..r(b+5)..' input='..r(b+2)..' crouch='..r(b+0x1D)..' cartR='..r(N.ENEMY_ROUTINE+15)..' frame='..r(N.ENEMY_FRAME+15)..' boost='..r(N.PLAYER_FAST_X_VEL_BOOST+p))end
 if f==1140 then
  print('Late collision '..mode..' p'..p..' power'..power..' xy='..r(N.SPRITE_X_POS+p)..'/'..r(N.SPRITE_Y_POS+p)..' landed='..tostring(landed)..' jumped='..tostring(jumped))
  assert(r(N.PLAYER_STATE+p)==1 and r(N.P1_NUM_LIVES+p)==startLives,'Terrain/platform handling must not lose a life')
  if mode=='ledge' then assert(landed,'Jump forward onto a solid ledge without an invisible wall')end
  if mode=='edge' then assert(r(N.SPRITE_X_POS+p)>80,'A legal spawn left of the normal boundary must be able to walk into the screen')end
  if mode=='tunnel' then assert(r(N.SPRITE_X_POS+p)>140,'A low corridor must allow walking in the crouched body')end
  if mode=='cart' then assert(jumped,'A carried player must be able to jump out of a cart')end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
