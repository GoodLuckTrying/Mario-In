local f=0
local writes={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function dump(name,first,last,kind)
 local out=assert(io.open(TEST_ROOT..'/build/'..name,'wb'))
 for a=first,last do out:write(string.char(emu.read(a,kind or emu.memType.nesDebug))) end
 out:close()
end
emu.addEventCallback(function()
 setPad(0,{start=f>=180 and f<190,right=f>=700 and f<730,left=f>=760 and f<790,up=f>=820 and f<840,a=f>=900 and f<910,b=f>=960 and f<970})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f==600 or f==850 then
  local msg='DMA '..f
  for i=0,252,4 do if r(0x200+i)<240 then msg=msg..string.format(' [%02X:%02X,%02X,%02X,%02X]',i,r(0x200+i),r(0x201+i),r(0x202+i),r(0x203+i)) end end
  print(msg)
 end
end,emu.callbackType.write,0x4014)
for _,addr in ipairs({0xd4,0xb6,0x4a6,0x36e,0x36f}) do
 emu.addMemoryCallback(function()
  local pc=emu.getState()['cpu.pc'];local key=addr*65536+pc
  if f>300 and not writes[key] then writes[key]=true;print(string.format('WRITE f%d %04X pc%04X',f,addr,pc)) end
 end,emu.callbackType.write,addr)
end
emu.addEventCallback(function()
 f=f+1
 if f>=700 then emu.write(0x4a6,48,emu.memType.nesDebug);emu.write(0x373,0,emu.memType.nesDebug) end
 if f%50==0 then print(string.format('F%d mode %d/%d floor%d x%d y%d hp%d pose%d state%02X input%02X/%02X',f,r(0x50),r(0x51),r(0x5f),r(0xd4),r(0xb6),r(0x4a6),r(0x36e),r(0x36f),r(0x14),r(0x15))) end
 if f==400 or f==600 or f==850 or f==1000 then
  dump('ram'..f..'.bin',0,0x7ff)
  dump('ppu'..f..'.bin',0,0x3fff,emu.memType.nesPpuDebug)
  local out=assert(io.open(TEST_ROOT..'/build/native'..f..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==1200 then emu.stop(0) end
end,emu.eventType.endFrame)
