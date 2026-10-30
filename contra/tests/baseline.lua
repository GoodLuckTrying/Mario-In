local f=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200 or f==400,right=f>=600 and f<660,a=f>=700 and f<720},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f%60==0 then print(string.format('f=%d game=%d levelroutine=%d level=%d mode=%d player=%d pos=%d,%d input=%02X',f,r(0x18),r(0x2C),r(0x30),r(0x22),r(0x90),r(0x334),r(0x31A),r(0xF1))) end
 if f==500 or f==900 then
  local o=assert(io.open(TEST_ROOT..'/build/base-'..f..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  local o=assert(io.open(TEST_ROOT..'/build/base-'..f..'.ram','wb'));for a=0,0x7FF do o:write(string.char(r(a))) end;o:close()
 end
 if f==960 then emu.stop(0) end
end,emu.eventType.endFrame)
