local f=0
local writes={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f>=200 and f<1700 and f%100<10,right=f>=1800 and f<1840,up=f>=1900 and f<1940,a=f>=2000 and f<2020,b=f>=2100 and f<2120})
 setPad(1,{})
end,emu.eventType.inputPolled)
for _,addr in ipairs({0x4d7,0x4ff,0x527,0x513,0x59f,0x499}) do
 emu.addMemoryCallback(function()
  local pc=emu.getState()['cpu.pc'];local key=addr*65536+pc
  if f>300 and not writes[key] then writes[key]=true;print(string.format('WRITE f%d %04X pc%04X',f,addr,pc)) end
 end,emu.callbackType.write,addr)
end
emu.addEventCallback(function()
 f=f+1
 if f%100==0 then print(string.format('F%d state%02X/%02X scene%02X count%02X/%02X scroll%02X input%02X/%02X x%02X:%02X y%02X:%02X z%02X:%02X vel%02X/%02X/%02X weight%d life%d',f,r(0x10),r(0x11),r(0x8c),r(3),r(0x4c),r(0x73),r(0x18),r(0x19),r(0x4c3),r(0x4d7),r(0x4eb),r(0x4ff),r(0x513),r(0x527),r(0x53b),r(0x54f),r(0x563),r(0x59f),r(0x3df))) end
 if f==1600 or f==1800 or f==2000 or f==2200 then
  local out=assert(io.open(TEST_ROOT..'/build/ram'..f..'.bin','wb'));for a=0,0x7ff do out:write(string.char(r(a))) end;out:close()
  out=assert(io.open(TEST_ROOT..'/build/ppu'..f..'.bin','wb'));for a=0,0x3fff do out:write(string.char(emu.read(a,emu.memType.nesPpuDebug))) end;out:close()
  out=assert(io.open(TEST_ROOT..'/build/native'..f..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==2500 then emu.stop(0) end
end,emu.eventType.endFrame)
