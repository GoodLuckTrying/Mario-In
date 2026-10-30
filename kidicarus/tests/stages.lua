-- Stage loading fixtures deliberately invoke native load entries.
-- They are integration smoke tests, not a controller playthrough.
local f=0
local updates=0
local stage=STAGE or 2
local power=POWER or 0
dofile(TEST_ROOT..'/tests/reload_stage.lua')
local root=(TEST_ROOT..'/build/')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,a=f>=780 and f<805,right=f>=740 and f<778,b=f>=740 and f<778},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function() if f>=700 then updates=updates+1 end end,emu.callbackType.exec,0x8000)
emu.addEventCallback(function()
 f=f+1
 if f==600 and stage~=2 then
  requestNativeStage(stage)
 end
 if f==730 then w(0x6804,power) end
 if f==740 or f==810 or f==880 then
  local p=string.format('stage-%d-power-%d-%d',stage,power,f)
  local o=assert(io.open(root..p..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  local o=assert(io.open(root..p..'.ram','wb'));for a=0,0x7ff do o:write(string.char(r(a))) end;o:close()
  local o=assert(io.open(root..p..'.wram','wb'));for a=0x6000,0x7fff do o:write(string.char(r(a))) end;o:close()
  local o=assert(io.open(root..p..'.chr','wb'));for a=0,0x1fff do o:write(string.char(emu.read(a,emu.memType.nesPpuDebug))) end;o:close()
  local o=assert(io.open(root..p..'.state.txt','w'));for k,v in pairs(emu.getState()) do o:write(tostring(k)..'='..tostring(v)..'\n') end;o:close()
 end
 if f>=900 then
  print('stage='..stage..' actual='..r(0xA0)..' bank='..r(0xB6)..' updates='..updates..' X='..r(0x723)..' Y='..r(0x720)..' power='..r(0x6804))
  assert(r(0xA0)==stage,'Native stage must stay active')
  assert(updates>20,'Mario update must run in native stage')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
