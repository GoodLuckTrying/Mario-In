dofile(TEST_ROOT..'/tests/common.lua')
local resetFrame=nil
local returned=nil
local fresh=false
function input(age)
 return{a=age>=40 and age<48,b=age>=40 and age<48,select=age>=40 and age<48,start=age>=40 and age<48}
end
emu.addMemoryCallback(function()
 if first and resetFrame and f-resetFrame>50 then fresh=true end
end,emu.callbackType.exec,H.SessionGate)
function tick(age)
 -- The native A+B+Select+Start reset combination returns to the legal/title
 -- flow. The common controller then starts another normal game.
 if age>=20 and not resetFrame then resetFrame=f;w(0x7811,7)end
 if first and r(N.gameMode)<4 then returned=returned or f end
 if returned and fresh and r(N.gameMode)==4 and r(0x7800)==0x4d then
  assert(r(0x7811)==0 and r(0x780c)==0,'new game must reset stomp/death state')
  finish('native reset returns to menus and a fresh Mario game')
 end
end
