local f=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{start=f>=200 and f<210,b=f>=500 and f%30<10});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==500 or f==900 then
  local a={};for i=0x3f10,0x3f1f do a[#a+1]=string.format('%02X',emu.read(i,emu.memType.nesPpuDebug)) end
  print(f..' palettes '..table.concat(a,',')..' mode '..r(0x00)..' state '..r(0x1b)..' player '..r(0x100)..' xy '..r(0x360)..','..r(0x320))
  local o=assert(io.open(TEST_ROOT..'/build/native-'..f..'.png','wb'));o:write(emu.takeScreenshot());o:close()
 end
 if f==900 then emu.stop(0) end
end,emu.eventType.endFrame)
