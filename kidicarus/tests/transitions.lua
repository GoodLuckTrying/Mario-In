local f=0
local cleared={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,right=f>=710 and f<725},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==600 then w(0x6804,2);w(0xAB,128) end
 if f==700 then assert(r(0x130)==1 and r(0xA0)==2,'1-1 must transition to 1-2');assert(r(0x6804)==2,'Fire power must survive a native level transition');print('1-1 to 1-2 passed') end
 if f==800 then w(0xAB,128) end
 if f==900 then assert(r(0x130)==2 and r(0xA0)==2,'1-2 must transition to 1-3');assert(r(0x6804)==2,'Fire power must survive the next level');print('1-2 to 1-3 passed') end
 if f==1000 then w(0xAB,128) end
 if f==1150 then
  print('Fortress actual mode='..r(0xA0)..' stage='..r(0x130)..' power='..r(0x6804))
  assert(r(0xA0)==3,'1-3 must transition into the native fortress')
  assert(r(0x6804)==2,'Fire power must survive a bank change')
  print('1-3 to fortress passed')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
