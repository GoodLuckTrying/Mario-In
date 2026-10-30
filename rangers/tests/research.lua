local f=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=(f%90==0),right=f>1600 and f<1800,a=f>=1700 and f<1720,b=f>=1750 and f<1800})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f%60==0 then
  local s=emu.getState()
  print(string.format('F%d PC%04X x%02X y%02X m%02X %02X %02X %02X %02X',f,s['cpu.pc'],r(0x68),r(0x510),r(0),r(1),r(2),r(3),r(4)))
 end
 if f==900 or f==1500 or f==1800 then
  local o=io.open(TEST_ROOT..'/build/native-'..f..'.png','wb');o:write(emu.takeScreenshot());o:close()
  local o=io.open(TEST_ROOT..'/build/ram-'..f..'.bin','wb')
  for a=0,0x7ff do o:write(string.char(r(a))) end;o:close()
 end
 if f==1800 then print('PASS native research');emu.stop(0) end
end,emu.eventType.endFrame)
