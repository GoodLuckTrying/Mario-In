dofile(TEST_ROOT..'/tests/common.lua')
function input(t)return{right=t>140 and t<250,b=t>180 and t<300 and t%12<6,a=t>160 and t<180}end
local startx=nil
local fires=0
emu.addMemoryCallback(function()if first then fires=fires+1 end end,emu.callbackType.exec,H.MarioFireSpawn_Create)
function tick(t)
 if menu and not first and f-menu==35 then screenshot('select-'..(CHAR or 0))end
 if t<0 then return end
 assert(r(H.CurrentCharacter)==(CHAR or 0),'only the selected brother enters play')
 assert(r(H.PlayerHealth)<=0x3f,'native health remains bounded')
 if t==140 then startx=r(H.PlayerXLo)+256*r(H.PlayerXHi)end
 if t==230 then
  screenshot('opening-'..(CHAR or 0));print('MOVE '..startx..' -> '..(r(H.PlayerXLo)+256*r(H.PlayerXHi))..' y '..r(H.PlayerYLo)..' state '..r(H.PlayerState)..' vel '..r(H.PlayerXVelocity))
  assert(r(H.PlayerXLo)+256*r(H.PlayerXHi)>startx+40,'SMB controller moves the selected brother')
  assert(r(0x7e15)<26,'SMB pose index stays bounded')
  screenshot('opening-'..(CHAR or 0))
 end
 if t==330 then
  assert(fires>=1,'big form throws real fireballs with B')
  assert(r(H.PlayerState)<7,'opening controller route remains alive')
  finish('SMB2 cold boot, brother selection, SMB movement/jump and fireball spawn')
 end
end
