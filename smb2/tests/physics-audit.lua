AREA=2
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil;local base=nil;local peak=9999
local hold=HOLD or 1
local function y()return r(H.PlayerYLo)+256*r(H.PlayerYHi)end
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 for row=0,0xe0,16 do for x=0,15 do w(0x6000+row+x,row>=176 and 0xd5 or 0x40)end end
 for a=0x7e00,0x7e26 do w(a,0)end
 w(0x7e13,0x70);w(0x7e20,0x70)
 w(H.PlayerXLo,80);w(H.PlayerXHi,0);w(H.PlayerYLo,144);w(H.PlayerYHi,0)
 w(H.PlayerHealth,SMALL and 15 or 31);w(H.PlayerCurrentSize,SMALL and 1 or 0)
 w(H.PlayerState,0);w(H.PlayerInAir,0);w(H.PlayerXVelocity,0);w(H.PlayerYVelocity,0)
 w(H.PlayerYSubpixel,0);w(H.PlayerXSubpixel,0)
 w(H.PlayerYAcceleration,0);w(H.PlayerXAcceleration,0)
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return{a=dt>=20 and dt<20+hold}
end
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 if dt==15 then base=y()end
 if dt>=20 and dt<105 then peak=math.min(peak,y())end
 if dt==110 then
  local rise=base-peak
  print('MEASURE SMB2 character'..(CHAR or 0)..' hold'..hold..' base'..base..' rise'..rise..' SMB1 '..(hold==1 and 24 or 64))
  assert(rise==(hold==1 and 24 or 64),'live SMB2 jump reproduces the exact SMB1 source arc')
  finish('live SMB2 tap/held jump matches the SMB1 reference')
 end
end
