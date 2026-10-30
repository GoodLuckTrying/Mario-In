local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then local x=12;w(0x434+x,0x30);w(0x584+x,0);w(0x4c0+x,0x0f);w(0x4a4+x,0);w(0x354+x,120);w(0x38c+x,160);w(0x568+x,100);w(0x300+x,0) end
 if frame==710 then print('HEART pose '..r(0x31c+12));emu.stop(0) end
end,emu.eventType.endFrame)
