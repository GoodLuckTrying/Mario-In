N=H
f=0;first=nil;done=false;menu=nil
function r(a)return emu.read(a,emu.memType.nesDebug)end
function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
function screenshot(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
end
function finish(message)print('PASS '..message);done=true;emu.stop(0)end
emu.addMemoryCallback(function()menu=menu or f end,emu.callbackType.exec,H.CharacterSelectMenuLoop)
emu.addMemoryCallback(function()first=first or f end,emu.callbackType.exec,H.HandlePlayerState)
emu.addMemoryCallback(function()
 if WORLD then w(H.CurrentWorld,WORLD)end
end,emu.callbackType.exec,H.GoToWorldStartingLevel)
emu.addMemoryCallback(function()
 if AREA then w(H.CurrentLevelArea,AREA);w(H.CurrentLevelArea_Init,AREA)end
end,emu.callbackType.exec,H.StartLevel)
emu.addEventCallback(function()
 if done then return end
 local pad={}
 if first then
  if input then pad=input(f-first)or{}end
 elseif menu then
  local t=f-menu
  if CHAR==3 then pad.right=t==20 end
  pad.a=t==50 or t>200 and f%90<4
 else pad.start=f%90<4;pad.a=f%90<4 end
 setPad(0,pad);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if tick then tick(first and f-first or -1)end
 assert(f<(MAX_FRAMES or 8000),'bounded SMB2 replay')
end,emu.eventType.endFrame)
