local f=0
local boot=0
local demoDraws=0
local demoUpdates=0
local gameUpdates=0
local leftDemo=false
local started=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=demoUpdates>100 and not started and f%90<3,b=started and f%20<5,a=started and f%120<30});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()boot=boot+1;assert(boot==1,'attract/gameplay must never reset the machine')end,emu.callbackType.exec,H.Boot)
emu.addMemoryCallback(function()
 if r(0x94)~=0 then demoUpdates=demoUpdates+1
 elseif demoUpdates>0 then started=true;gameUpdates=gameUpdates+1 end
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()if r(0x94)~=0 then demoDraws=demoDraws+1 end end,emu.callbackType.exec,H.DrawMario)
emu.addEventCallback(function()
 f=f+1
 if demoUpdates>0 and r(0x94)==0 then leftDemo=true end
 if gameUpdates>60 then
  assert(demoDraws>30 and demoUpdates>50,'demo includes real Mario graphics and movement')
  print('PASS native attract demo renders Mario, ends, starts a normal game and never resets; demo draws '..demoDraws);emu.stop(0)
 end
 assert(f<9000,'attract/demo/game transition completes; draws '..demoDraws..' updates '..demoUpdates..' left '..tostring(leftDemo)..' game '..gameUpdates)
end,emu.eventType.endFrame)
