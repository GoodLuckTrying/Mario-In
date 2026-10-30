local f=0;local late=0;local total=0;local updates=0;local lineMax=-1
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f<1600 and f%180<3,b=f>=1700 and f%32<2,up=f>=1700 and f%256<128,a=f>=1700 and f%32>=16 and f%32<18,left=f>=2400 and f%180>=100 and f%180<104,right=f>=2400 and f%180>=140 and f%180<144,down=f>=2400 and f%180>=70 and f%180<74});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()updates=updates+1 end,emu.callbackType.exec,0xa669)
emu.addMemoryCallback(function(a,v)
 total=total+1;local s=emu.getState();local line=s['ppu.scanline']
 if line>=0 and line<240 and s['ppu.mask.backgroundEnabled']then
  late=late+1;lineMax=math.max(lineMax,line)
  if late<=20 then print('LATE '..f..' line '..line..':'..s['ppu.cycle']..' pc '..string.format('%04X',s['cpu.pc'])..' addr '..a..' val '..v..' pose '..r(0x61)..' tasks '..r(0x1a)..' dma '..r(0x17)..' engine '..r(0x1c))end
 end
end,emu.callbackType.write,0x2006,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==5000 then print('TIMING frames '..f..' updates '..updates..' late '..late..' total '..total..' worst '..lineMax);print('PASS timing recorded');emu.stop(0)end
end,emu.eventType.endFrame)
