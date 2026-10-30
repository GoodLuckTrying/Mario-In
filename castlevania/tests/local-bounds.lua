local frame=0
local checking=false
local checks=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120,right=frame>=699 and frame<=700,left=frame>=709 and frame<=710},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 or frame==710 then
  w(0x38c,frame==700 and 239 or 9);w(0x3a8,128);w(0x3c,frame==700 and 5 or 6)
  w(0x6002,128);w(0x6003,frame==700 and 2 or 253);checking=true
 end
end,emu.callbackType.exec,0x989a)
emu.addMemoryCallback(function()
 if checking then
  checking=false
  local expected=frame==700 and 239 or 8
  if r(0x38c)~=expected then print('FAIL skipped local bound '..r(0x38c));emu.stop(1);return end
  print('Local bound '..expected..' passed at running speed')
  checks=checks+1
  if frame==710 then emu.stop(checks==2 and 0 or 1) end
 end
end,emu.callbackType.exec,0x990a)
emu.addEventCallback(function()
 frame=frame+1
 if frame==699 or frame==709 then
  local speed=frame==699 and 40 or 216
  w(0x6071,speed);w(0x6073,40);w(0x6076,frame==699 and 1 or 2);w(0x6077,frame==699 and 1 or 2)
 end
 if frame==800 then print('FAIL missing boundary callbacks');emu.stop(1) end
end,emu.eventType.endFrame)
