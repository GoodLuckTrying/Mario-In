AREA=2
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil;local poses={}
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 for row=0,0xe0,16 do for x=0,15 do w(0x6000+row+x,row>=176 and 0xd5 or 0x40)end end
 w(H.PlayerXLo,40);w(H.PlayerXHi,0);w(H.PlayerYLo,144);w(H.PlayerYHi,0)
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0)
 w(H.PlayerState,0);w(H.PlayerInAir,0);w(H.PlayerXVelocity,0);w(H.PlayerYVelocity,0)
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)return{right=seeded~=nil}end
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 if dt>=15 and dt<75 then poses[r(0x7e15)]=true end
 if dt==75 then
  local p=SMALL and 12 or 0
  assert(poses[p]and poses[p+1]and poses[p+2],'walking cycles all three original SMB1 frames')
  assert(not poses[23]and not poses[24],'a walking step is never replaced by the standing pose')
  finish('all three distinct SMB1 walking frames for the selected form')
 end
end
