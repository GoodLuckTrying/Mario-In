dofile(TEST_ROOT..'/tests/common.lua')
function input(t)return {right=t>100 and t<300,a=t==130,b=t>160,up=t>300}end
emu.addMemoryCallback(function()
 if first and f-first>100 and f-first<180 and f%10==0 then print('CTRL '..f..' pad '..r(H.Player1JoypadHeld)..' x '..r(H.PlayerXLo)..' vx '..r(H.PlayerXVelocity)..' state '..r(H.PlayerState)..' air '..r(H.PlayerInAir))end
end,emu.callbackType.exec,H.MarioControl)
emu.addMemoryCallback(function()
 if first and f-first>100 and f-first<180 and f%10==0 then print('ENDCTRL '..f..' vx '..r(H.PlayerXVelocity)..' dir '..r(0x7e0e)..' left '..r(0x7e07)..' right '..r(0x7e08))end
end,emu.callbackType.exec,H.MarioControl_Exit)
function tick(t)
 if t==350 then screenshot('debug');finish('debug')end
end
