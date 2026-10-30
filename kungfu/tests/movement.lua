local f=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f>=180 and f<190,right=f>=700 and f<760,left=f>=820 and f<880,up=f>=940 and f<960,b=f>=1050 and f<1052})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 for i=0,5 do w(0x80+i,0)end
 w(0x373,0);w(0x374,0)
 if f%10==0 and f>=690 then print(string.format('F%d x%04X y%d inp%02X speed%02X force%02X frac%02X dir%d nativ%d air%d vy%02X',f,r(0xd4)+r(0xe5)*256,r(0xb6),r(0x6a),r(0x7d01),r(0x7d02),r(0x7d12),r(0x7d07),r(0x67),r(0x7c08),r(0x7c05)))end
 if f==800 or f==960 then print(string.format('SPR active%02X x%d pos%d bank%d mask%02X oam%02X,%02X,%02X,%02X',r(0x86),r(0x94),r(0xb6),r(0x7c0f),r(0x11),r(0x218),r(0x219),r(0x21a),r(0x21b))); local o=assert(io.open(TEST_ROOT..'/build/mario'..f..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if f==1150 then emu.stop(0)end
end,emu.eventType.endFrame)
