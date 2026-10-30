dofile(TEST_ROOT..'/tests/common.lua')
local saved=nil
local paused=false
emu.addMemoryCallback(function()paused=true end,emu.callbackType.exec,H.ShowPauseScreen)
function input(t)return{b=t==135 or t==140 or t==190,a=t>180 and t<220,right=t>180 and t<220,start=t==150 or t==250}end
function tick(t)
 if t==165 then
  assert(paused,'Start must enter the native pause screen on the solid-ground fixture')
  saved={}
  for _,a in ipairs({H.PlayerXLo,H.PlayerYLo,H.PlayerXVelocity,H.PlayerYVelocity,0x7e11,0x7e12,0x7e40,0x7e47,0x7e48,H.ObjectXLo+7,H.ObjectYLo+7,H.ObjectXLo+8,H.ObjectYLo+8})do saved[a]=r(a)end
 end
 if t>170 and t<245 then for a,v in pairs(saved)do assert(r(a)==v,'native pause freezes movement, gravity, projectiles and lifetimes')end end
 if t==280 then finish('native pause/resume freezes Mario/Luigi and fireballs')end
end
