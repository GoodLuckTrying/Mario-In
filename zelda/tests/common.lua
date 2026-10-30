f=0;first=nil;done=false
function r(a)return emu.read(a,emu.memType.nesDebug)end
function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
function screenshot(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
end
function finish(message)print('PASS '..message);done=true;emu.stop(0)end
local registration=nil
emu.addMemoryCallback(function()
 if LEVEL and r(H.GameSubmode)==0 then w(H.CurLevel,LEVEL)end
end,emu.callbackType.exec,H.InitMode2)
emu.addEventCallback(function()
 if done then return end
 local pad={}
 local mode=r(H.GameMode)
 if first then
  if input then pad=input(f-first)or{}end
 elseif mode==14 and r(H.IsUpdatingMode)==1 then
  registration=registration or f
  local t=f-registration
  pad.a=t==15;pad.select=t==25 or t==35 or t==45;pad.start=t==60
 else pad.start=f%60==5 end
 setPad(0,pad);setPad(1,input2 and input2(first and f-first or -1)or{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(H.GameMode)==5 and r(H.IsUpdatingMode)==1 then first=first or f end
end,emu.callbackType.exec,H.UpdatePlayer)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if tick then tick(first and f-first or -1)end
 assert(f<(MAX_FRAMES or 5000),'bounded Zelda replay: mode '..r(H.GameMode)..' sub '..r(H.GameSubmode))
end,emu.eventType.endFrame)
