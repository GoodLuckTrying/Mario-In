local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 then
  -- New candle has the same Y as the previous candle's raised position.
  w(0x434+10,0x28);w(0x354+10,176);w(0x38c+10,220);w(0x300+10,0)
  w(0x608a,1);w(0x60ea,176);w(0x610a,2);w(0x4e6,4);w(0x612a,r(0x46))
  w(0x60aa,3);w(0x60ca,100)
  -- Reuse a former pickup for a native enemy too.
  w(0x434+11,1);w(0x354+11,160);w(0x38c+11,230);w(0x300+11,0);w(0x60ab,3)
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then
  assert(r(0x434+10)==0x28 and r(0x354+10)==176,'Reused lamp must retain its native position')
  assert(r(0x4e6)==4 and r(0x60aa)==0,'Native spawn identity must survive while stale pickup clears')
  assert(r(0x434+11)==1 and r(0x60ab)==0,'Stale pickup must not erase a new enemy')
  print('Candle and enemy slot reuse passed');emu.stop(0)
 end
end,emu.eventType.endFrame)
