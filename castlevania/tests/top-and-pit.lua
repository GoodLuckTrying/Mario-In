local frame=0
local minimum={255,255}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120,a=(frame>=700 and frame<725) or (frame>=740 and frame<765)},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 or frame==740 then
  w(0x6001,frame==700 and 0 or 1);w(0x3f,32);w(0x354,32);w(0x46c,1);w(0x6005,251);w(0x6004,0);w(0x6006,0);w(0x6009,40);w(0x607d,144);w(0x607e,32)
  for a=0x5a0,0x6ff do w(a,0) end
 end
 if (frame>=701 and frame<=735) or (frame>=741 and frame<=775) then
  local n=frame<740 and 1 or 2
  minimum[n]=math.min(minimum[n],r(0x3f))
  assert(r(0x46c)==1 and r(0x45)==64,'Top of screen must not wrap into pit death')
 end
 if frame==780 then
  assert(minimum[1]==0 and minimum[2]==0,'Both forms must reach the screen coordinate ceiling')
  w(0x3f,220);w(0x354,220);w(0x46c,1);w(0x6005,4);w(0x6004,0);w(0x6006,0)
 end
 if frame==782 then
  assert(r(0x46c)==8,'Falling into a real pit must still invoke native death')
  print('Top coordinate boundary and native pit death passed');emu.stop(0)
 end
end,emu.eventType.endFrame)
emu.addMemoryCallback(function() if frame>=700 then for x=3,23 do w(0x434+x,0);w(0x60a0+x,0) end end end,emu.callbackType.exec,0xcf19)
