local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local inject=false
emu.addEventCallback(function() emu.setInput({start=frame==120,right=frame>=700 and frame<710,left=frame>=710 and frame<720},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 or frame==710 then
  w(0x38c,frame==700 and 127 or 129);w(0x3a8,128);w(0x3c,frame==700 and 5 or 6)
  w(0x2e,64);w(0x2f,0);w(0x2d,0)
  w(0x6002,128);w(0x6003,frame==700 and 2 or 253);inject=true
 end
end,emu.callbackType.exec,0x989a)
emu.addMemoryCallback(function()
 if inject then
  inject=false
  if r(0x38c)~=128 then print('FAIL center crossing frame '..frame..' x '..r(0x38c));emu.stop(1);return end
  assert(r(0x2e)==(frame==700 and 66 or 63) and r(0x2f)==0,'Camera must retain the crossing overshoot')
  assert(r(0x40)==(frame==700 and 194 or 191) and r(0x41)==0,'Crossing must preserve full world movement')
  assert(r(0x3a8)==0,'Crossing must preserve the SMB position fraction')
  print('Center crossing frame '..frame..' passed')
  if frame==710 then emu.stop(0) end
 end
end,emu.callbackType.exec,0x989d)

emu.addEventCallback(function()
 frame=frame+1
 if frame==700 or frame==710 then print('fixture frame '..frame..' mode '..r(0x18)) end
 if frame==800 then print('FAIL missing crossing callbacks');emu.stop(1) end
end,emu.eventType.endFrame)
