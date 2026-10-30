AREA=1
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local planted=nil
local created=0
emu.addMemoryCallback(function()if seeded then created=created+1 end end,emu.callbackType.exec,H.loc_BANK0_9080)
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0);w(H.PlayerState,0);w(H.PlayerDucking,0);w(H.PlayerInAir,0);w(H.PlayerXVelocity,0)
 w(H.PlayerXLo,112)
 local base=0x6000+r(H.PlayerYHi)*240
 local row=(r(H.PlayerYLo)+32)&0xf0
 for x=0,15 do w(base+row+x,0xd5)end
 planted=base+row-16+(r(H.PlayerXLo)//16)
 w(planted,0x44)
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)return{b=seeded and f-seeded==5}end
function tick(t)
 if not seeded then return end
 if f-seeded==100 then
  assert(created==1 and r(H.HoldingItem)==1,'one B press plucks a native background plant and carries its object: created '..created..' hp '..r(H.PlayerHealth)..' y '..r(H.PlayerYLo)..' planted '..r(planted)..' holding '..r(H.HoldingItem))
  assert(r(planted)~=0x44,'native tile replacement removes the plant')
  local i=r(H.ObjectBeingCarriedIndex)
  assert(r(0x7e40+i)==0,'plucked object is never mistaken for a fireball')
  finish('native background plant pickup, tile removal and object priority over fireballs')
 end
end
