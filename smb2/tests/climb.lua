AREA=1
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil;local poses={};local base=nil;local stopped=nil
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 for row=0,0xe0,16 do for col=0,15 do w(0x6000+row+col,col==7 and 0xc2 or 0x40)end end
 w(H.PlayerXLo,112);w(H.PlayerXHi,0);w(H.PlayerYLo,160);w(H.PlayerYHi,0)
 w(H.PlayerState,1);w(H.PlayerDirection,LEFT and 0 or 1);w(H.PlayerAnimationFrame,10)
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0)
 w(H.PlayerXVelocity,0);w(H.PlayerYVelocity,0);base=160
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return{up=dt<45,down=dt>=65 and dt<85}
end
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 assert(r(H.PlayerState)==1,'native vine attachment stays active')
 assert(r(H.PlayerDirection)==(LEFT and 0 or 1),'climbing never flips the whole character')
 if dt>=5 and dt<45 then poses[r(0x7e15)]=true end
 if dt==46 then stopped=r(0x7e15);assert(r(H.PlayerYLo)<base-20,'Up actually climbs the vine')end
 if dt>47 and dt<64 then assert(r(0x7e15)==stopped,'climbing animation rests when motion stops')end
 if dt==85 then
  local p=SMALL and 20 or 8
  assert(poses[p]and poses[p+1],'climbing uses two distinct SMB frames')
  screenshot('climb-'..(CHAR or 0)..'-'..tostring(SMALL)..'-'..tostring(LEFT))
  finish('native up/down vine movement, stable facing, two climbing frames and idle pause')
 end
end
