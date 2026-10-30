local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 then
  w(0x6001,2); w(0x600d,0); w(0x5b,0)
  w(0x434+10,4); w(0x60a0+10,3); w(0x60c0+10,100)
  w(0x38c+10,r(0x38c)); w(0x354+10,r(0x3f)-22); w(0x300+10,0)
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then
  print('Heart approaching: power='..r(0x6001)..' picked='..r(0x6047)..' actor='..r(0x4e)..' ai='..r(0x43e)..' drop='..r(0x60aa)..' y='..r(0x35e))
  if r(0x6001)~=2 then emu.stop(1); return end
 end
 if frame==710 then
  print('Heart collected: power='..r(0x6001)..' picked='..r(0x6047))
  emu.stop((r(0x6001)==2 and r(0x6047)==1) and 0 or 1)
 end
end,emu.eventType.endFrame)
