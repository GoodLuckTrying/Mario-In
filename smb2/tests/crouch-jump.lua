AREA=2
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil;local base=nil;local normal=9999;local charged=9999;local charge=0
local baseSeen=false;local flashSeen=false;local readyFrames=0
local normalColors=(CHAR==3)and(SMALL and{0x30,0x27,0x19}or{0x37,0x27,0x19})or(SMALL and{0x16,0x27,0x18}or{0x37,0x27,0x16})
local chargeColors=(CHAR==3)and(SMALL and{0x37,0x37,0x29}or{0x30,0x37,0x29})or(SMALL and{0x26,0x37,0x28}or{0x30,0x37,0x27})
local function paletteEquals(colors)
 for i=1,3 do if emu.read(0x3f10+i,emu.memType.nesPpuDebug)~=colors[i]then return false end end
 return true
end
local function y()
 local v=r(H.PlayerYLo)+256*r(H.PlayerYHi)
 return v>=32768 and v-65536 or v
end
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 for row=0,0xe0,16 do for x=0,15 do w(0x6000+row+x,row>=176 and 0xd5 or 0x40)end end
 w(H.PlayerXLo,80);w(H.PlayerXHi,0);w(H.PlayerYLo,144);w(H.PlayerYHi,0)
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0)
 w(H.PlayerState,0);w(H.PlayerInAir,0);w(H.PlayerXVelocity,0);w(H.PlayerYVelocity,0)
 w(H.PlayerYAcceleration,0);w(H.PlayerXAcceleration,0)
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return{down=dt>=110 and dt<(HELD and 196 or 180),a=(dt>=20 and dt<35)or(dt>=195 and dt<210)}
end
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 if dt==15 then base=y()end
 if dt>=20 and dt<100 then normal=math.min(normal,y())end
 if dt>=120 and dt<165 then assert(paletteEquals(normalColors),'partial charge keeps the regular form colors')end
 if dt>=174 and dt<=192 then
  readyFrames=readyFrames+1
  assert(r(H.CrouchJumpTimer)>=60,'charge-ready flash requires a completed charge')
  assert(paletteEquals(normalColors)or paletteEquals(chargeColors),'ready flash uses the selected brother and size colors')
  assert(r(H.SpriteDMAArea+0x2a)&3==0,'visible player sprites use the flashing player palette')
  if paletteEquals(normalColors)then baseSeen=true end
  if paletteEquals(chargeColors)then
   if not flashSeen then screenshot('charge-flash-'..(CHAR or 0)..'-'..tostring(SMALL)..'-'..tostring(HELD))end
   flashSeen=true
  end
 end
 if dt==190 then charge=r(H.CrouchJumpTimer);assert(charge>=60,'releasing Down preserves a full charged jump')end
 if dt>=195 and dt<285 then charged=math.min(charged,y())end
 if dt>=198 and dt<240 then assert(paletteEquals(normalColors),'jumping consumes the charge and restores regular form colors')end
 if TRACE and dt%10==0 then print('CROUCH '..dt..' y '..y()..' charge '..r(H.CrouchJumpTimer)..' air '..r(H.PlayerInAir))end
 if dt==285 then
  assert(normal<base-25,'the normal controller jump has a real apex')
  assert(charged<normal-30,'the charged crouch jump rises substantially higher: '..normal..'/'..charged)
  assert(r(H.CrouchJumpTimer)==0,'jump consumes the full charge')
  assert(baseSeen and flashSeen and readyFrames>=15,'fully charged player visibly alternates regular and bright colors')
  finish('native crouch charge, visible ready flash, stored full charge and a higher controller-driven jump with restored colors')
 end
end
