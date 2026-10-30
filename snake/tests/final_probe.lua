local f=0
local seen=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addMemoryCallback(function()if not seen then w(0xaa,9);seen=true end end,emu.callbackType.exec,0x82BF)
emu.addEventCallback(function()setPad(0,{start=f>=700 and f<710});setPad(1,{})end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if f>700 and f%100==0 then print(string.format('F%d kind%02X/%02X pos%02X/%02X z%02X/%02X b3%02X/%02X af%02X/%02X camera%02X%02X/%02X%02X phase%02X%02X chr%02X',f,r(0x49b),r(0x49c),r(0x3b7),r(0x3cb),r(0x527),r(0x513),r(0x5b3),r(0x5b4),r(0x4af),r(0x4b0),r(0x6d),r(0x6e),r(0x6f),r(0x70),r(0x11),r(0x10),r(0xe2)))end
 if f==1800 then local o=assert(io.open(TEST_ROOT..'/build/final-probe.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if f==2400 then emu.stop(0)end
end,emu.eventType.endFrame)
