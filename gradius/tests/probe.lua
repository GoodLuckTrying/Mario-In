local f=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local count=0
emu.addEventCallback(function() setPad(0,{start=f>=200 and f<210,a=f>=490});setPad(1,{}) end,emu.eventType.inputPolled)
for _,pc in ipairs({0x80a7,0x80aa,0x80ad,0x80b3}) do
 emu.addMemoryCallback(function()
  if f==550 then local s=emu.getState();print(string.format('PC %04X line %s cycle %s lock %d',pc,tostring(s['ppu.scanline']),tostring(s['cpu.cycleCount']),r(4))) end
  if pc==0x80b3 and f>=500 then count=count+1 end
 end,emu.callbackType.exec,pc)
end
emu.addMemoryCallback(function()
 if f>=500 and f<530 then print(string.format('SHOT %d %d XY %d %d VY %d',f,r(0x123),r(0x363),r(0x323),r(0x7020))) end
end,emu.callbackType.exec,H.FireLoop)
emu.addEventCallback(function()
 f=f+1
 if f==550 then local o=assert(io.open(TEST_ROOT..'/build/fire.png','wb'));o:write(emu.takeScreenshot());o:close() end
 if f==650 then print('updates '..count..'/150');emu.stop(0) end
end,emu.eventType.endFrame)
