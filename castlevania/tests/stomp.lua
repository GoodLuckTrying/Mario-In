local frame=0
local actor=19
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function fixture(y,old)
 w(0x6001,1); w(0x600d,0); w(0x5b,0); w(0x45,64)
 w(0x3f,y); w(0x354,y); w(0x6008,old); w(0x6005,2); w(0x6004,0); w(0x46c,1)
 for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x60a0}) do w(base+actor,0) end
 w(0x434+actor,1); w(0x38c+actor,r(0x38c)); w(0x354+actor,160); w(0x31c+actor,0x50)
end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 then fixture(130,128) end
 if frame==710 then fixture(126,124) end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if frame==710 and emu.getState()["cpu.x"]==actor then w(0x354+actor,154) end
end,emu.callbackType.exec,0xea77)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 or frame==711 then
  local expected=frame==701 and 1 or 2
  local damaged=r(0x434+actor)~=1
  local ok=r(0x6045)==expected and r(0x6005)>=128 and damaged and r(0x6001)==1 and r(0x45)==64
  print('Stomp '..expected..': count='..r(0x6045)..' enemy AI='..r(0x434+actor)..' power='..r(0x6001)..' health='..r(0x45))
  if not ok then emu.stop(1); return end
  if frame==711 then emu.stop(0) end
 end
end,emu.eventType.endFrame)
