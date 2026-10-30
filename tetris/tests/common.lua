f=0
first=nil
done=false
function r(a)return emu.read(a,emu.memType.nesDebug)end
function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
function screenshot(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
end
function finish(message)
 print('PASS '..message);done=true;emu.stop(0)
end
emu.addEventCallback(function()
 if done then return end
 local pad={}
 if r(N.gameMode)<4 then
  pad.start=f%90<4
  if TYPE_B and r(N.gameMode)==2 and r(0x78a1)==2 then pad.right=f%30>=10 and f%30<14 end
 elseif first and input then pad=input(f-first)or{}end
 setPad(0,pad);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if LEVEL then w(N.player1_startLevel,LEVEL)end
end,emu.callbackType.exec,N.gameModeState_initGameBackground)
emu.addMemoryCallback(function()first=first or f end,emu.callbackType.exec,H.UpdateGate)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if tick then tick(first and f-first or -1)end
 assert(f<(MAX_FRAMES or 6000),'bounded Tetris replay must finish')
end,emu.eventType.endFrame)
