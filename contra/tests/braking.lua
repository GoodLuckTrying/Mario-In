local f=0
local p=PLAYER or 0
local b=0x6000+p*128
local mode=MODE or 'ground'
local samples={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for q=0,1 do setPad(q,{start=q==0 and (f==120 or f==200 or f==400),select=q==0 and f==180,left=q==p and f>=720 and f<770,right=q==p and REVERSE and f>=770 and f<778,b=q==p and f>=720 and (HOLD_B or f<770)}) end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<710 or f>1100 or emu.getState()['cpu.x']~=p then return end
 w(N.VERTICAL_SCROLL,0);w(N.HORIZONTAL_SCROLL,0);w(N.LEVEL_STOP_SCROLL,255)
 for i=0,127 do w(N.BG_COLLISION_DATA+i,(i%64)//4==11 and 0x55 or 0) end
 for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end
 if f<715 then
  w(N.SPRITE_Y_POS+p,164);w(N.SPRITE_X_POS+p,180);w(b+5,0);w(b+0x18,0);w(b+0x19,0);w(b+0x17,0);w(b+6,0);w(b+7,0)
 end
 w(b+0x4c,2)
 w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,250)
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f>=800 and f%30==0 then
  samples[#samples+1]={f,r(N.SPRITE_X_POS+p),r(b+6),r(b+5),r(b+7),r(N.PLAYER_X_VELOCITY+p)}
  print(table.concat(samples[#samples],','))
 end
 if f==1100 then
  assert(r(b+6)==0,'Horizontal velocity must settle to zero after releasing movement')
  assert(r(N.PLAYER_X_VELOCITY+p)==0,'Native movement must not keep a stale backwards step')
  assert(samples[#samples][2]==samples[#samples-4][2],'Position must stop changing on level ground')
  print('PASS ground braking player '..p);emu.stop(0)
 end
end,emu.eventType.endFrame)
