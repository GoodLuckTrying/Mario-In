local f=0
local started=0
local durations={}
local updates=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,b=FIRE and ((f>=520 and f<523) or (f>=530 and f<533))},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 started=emu.getState()['cpu.cycleCount']
end,emu.callbackType.exec,0xC866)
emu.addMemoryCallback(function()
 if f>=500 then durations[#durations+1]=emu.getState()['cpu.cycleCount']-started end
end,emu.callbackType.exec,0xC89F)
emu.addMemoryCallback(function()
 if f>=500 then updates=updates+1 end
end,emu.callbackType.exec,0xCBB6)
emu.addEventCallback(function()
 f=f+1
 if f==510 and FIRE then emu.write(0x6804,2,emu.memType.nesDebug) end
 if f>=700 then
  table.sort(durations)
  print('Updates per 200 frames: '..updates..'; NMI samples='..#durations..'; median='..tostring(durations[math.floor(#durations/2)])..'; max='..tostring(durations[#durations]))
  emu.stop(0)
 end
end,emu.eventType.endFrame)
