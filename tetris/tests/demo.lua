local f=0
local started=nil
local returned=nil
local steps=0
local done=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()if r(N.gameMode)==5 then steps=steps+1 end end,emu.callbackType.exec,H.UpdateGate)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if r(N.gameMode)==5 then started=started or f end
 if started and r(N.gameMode)==1 then returned=returned or f end
 if returned and f-returned>=80 then
  assert(steps>50,'the native attract sequence must run with Mario')
  print('PASS attract demo plays and returns to the title');done=true;emu.stop(0)
 end
 assert(f<12000,'attract demo must not hang on gameplay or title return')
end,emu.eventType.endFrame)
