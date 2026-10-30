-- Stress the native 16-slot gun pool alongside all four Mario fireballs.
local f=0
local stage=STAGE or 0
local peaks={0,0}
local bad=0
local seen={{},{}}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for p=0,1 do
  setPad(p,{start=p==0 and (f==120 or f==200 or f==400),select=p==0 and f==180,b=f>=1000 and f%6==0})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for a=0x680,0x6FF do w(a,0x55) end
 for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0) end
 for p=0,1 do
  local b=0x6000+p*128
  w(b+4,2);w(b+0x35,0);w(b+0x4C,2);w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,200)
  if f<945 then w(N.SPRITE_X_POS+p,80+p*80);w(N.SPRITE_Y_POS+p,164);w(b+5,0);w(b+0x18,0);w(b+0x19,0) end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f<940 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 local state=emu.getState()
 if state['ppu.scanline']>=0 and state['ppu.scanline']<240 then bad=bad+1 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==480 and stage~=0 then w(N.CURRENT_LEVEL,stage);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f>=990 and (f-990)%160==0 and f<=1630 then
  local weapon=math.floor((f-990)/160)
  for p=0,1 do w(N.P1_CURRENT_WEAPON+p,weapon) end
  for s=0,15 do w(N.PLAYER_BULLET_SLOT+s,0);w(N.PLAYER_BULLET_SPRITE_CODE+s,0);w(N.PLAYER_BULLET_ROUTINE+s,0) end
  for s=0,3 do w(0x6180+s,0) end
 end
 if f>=1000 and f<1790 then
  local guns=0;local fire=0
  for s=0,15 do
   if r(N.PLAYER_BULLET_SLOT+s)~=0 then
    guns=guns+1
    local p=r(N.PLAYER_BULLET_OWNER+s);local kind=(r(N.PLAYER_BULLET_SLOT+s)&15)-1
    assert(p<2 and kind>=0 and kind<=4,'Native projectile ownership/type must survive simultaneous fire')
    seen[p+1][kind]=true
   end
  end
  for s=0,3 do
   if r(0x6180+s)~=0 then
    fire=fire+1
    assert(r(0x61C0+s)==s%2,'Mario fireball ownership must remain independent of gun slots')
   end
  end
  peaks[1]=math.max(peaks[1],guns);peaks[2]=math.max(peaks[2],fire)
 end
 if f==1800 then
  for p=1,2 do for kind=0,4 do assert(seen[p][kind],'Both players must exercise every gun together') end end
  print('Co-op armory stage='..stage..' peak guns='..peaks[1]..' fireballs='..peaks[2])
  assert(bad==0,'Full co-op volleys must preserve vblank graphics timing')
  assert(peaks[1]>10 and peaks[2]==4,'Native gun volleys and four fireballs must coexist without overwriting either pool')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
