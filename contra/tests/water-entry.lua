-- Build running speed with real controllers, then switch native floor cells
-- to water at a native update boundary. Position pinning keeps both actors
-- in independent test columns; velocity/forces/input stay engine-owned.
local f=0;local ticks=0;local ready=false;local wet={false,false}
local entered={false,false};local wetUpdates={0,0};local peak={0,0}
local initialized={false,false};local observations=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function magnitude(v)return v<128 and v or 256-v end
local directions=LEFT and {2,1}or {1,2}
emu.addEventCallback(function()
 for p=0,1 do
  local drive=ready and (p==0 and wetUpdates[1]<15 or p==1 and not wet[2])
  setPad(p,{start=p==0 and(f==120 or f==200 or f==400),select=p==0 and f==180,
   right=drive and directions[p+1]==1,left=drive and directions[p+1]==2,b=ready})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 or r(N.GAME_ROUTINE_INDEX)~=5 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 ready=true;ticks=ticks+1
 wet[1]=ticks>=85;wet[2]=ticks>=120
 for a=N.BG_COLLISION_DATA,N.BG_COLLISION_DATA+127 do w(a,0)end
 for nt=0,1 do for row=12,13 do
  for p=0,1 do w(N.BG_COLLISION_DATA+nt*64+row*4+1+p*2,wet[p+1]and 0xaa or 0x55)end
 end end
 w(N.HORIZONTAL_SCROLL,0);w(N.VERTICAL_SCROLL,0);w(N.LEVEL_STOP_SCROLL,255);w(N.FRAME_SCROLL,0)
 for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
 for p=0,1 do
  local b=0x6000+p*128
  w(N.SPRITE_X_POS+p,80+p*128);w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,240)
  w(b+4,POWER or 0);w(b+0x35,0);w(b+0x4c,2)
  if not initialized[p+1]then
   w(N.SPRITE_Y_POS+p,180);w(N.PLAYER_STATE+p,1);w(N.PLAYER_HIDDEN+p,0)
   w(N.PLAYER_JUMP_STATUS+p,0);w(N.PLAYER_Y_FAST_VELOCITY+p,0);w(N.PLAYER_Y_FRACT_VELOCITY+p,0)
   for _,o in ipairs({5,6,7,8,9,10,0x16,0x17,0x18,0x19,0x1d,0x47,0x4d})do w(b+o,0)end
   w(b+0xb,directions[p+1]);w(b+0xc,directions[p+1]);initialized[p+1]=true
  end
 end
end,emu.callbackType.exec,N.exe_game_routine)
-- Sprite selection follows this player's completed movement update.
emu.addMemoryCallback(function()
 if not ready then return end
 local p=emu.getState()['cpu.x'];if p>1 then return end
 local b=0x6000+p*128;local speed=magnitude(r(b+6))
 if not wet[p+1]then
  peak[p+1]=math.max(peak[p+1],speed)
  if p==1 and wet[1]then
   assert(speed==0x28 and r(b+0x14)==1,'the other player must retain full dry-land running speed while Mario swims')
  end
  return
 end
 assert(r(b+0x47)==1 and r(b+0x14)==0,'native water contact must activate swimming')
 assert(speed<=0x18 and r(b+8)<=0x18,'player '..p..' cannot carry land running velocity into swimming: speed '..speed..' abs '..r(b+8))
 if not entered[p+1]then
  assert(peak[p+1]>=0x28,'build full land running speed with controllers before water entry')
  assert(r(b+9)==0 and r(b+10)==0,'water entry clears land running flags/timer')
  entered[p+1]=true
 end
 wetUpdates[p+1]=wetUpdates[p+1]+1;observations=observations+1
end,emu.callbackType.exec,H.RenderGate)
emu.addEventCallback(function()
 f=f+1
 if wetUpdates[1]>=100 and wetUpdates[2]>=60 then
  assert(entered[1]and entered[2]and observations>=160,'both controllers enter independently and retain water speed with B held and direction released')
  print('PASS water entry power '..(POWER or 0)..' left '..tostring(LEFT)..': land speed '..peak[1]..'/'..peak[2]..', '..wetUpdates[1]..'/'..wetUpdates[2]..' swimming updates capped at SMB water speed')
  emu.stop(0)
 end
 assert(f<1600,'running entry and sustained swimming must complete')
end,emu.eventType.endFrame)
