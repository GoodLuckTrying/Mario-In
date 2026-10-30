local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120,b=frame>=710,right=frame>=710},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame%100==0 and frame>=700 then print(frame..' mode '..r(0x18)..' stage '..r(0x28)..' world '..r(0x40)+256*r(0x41)..' x '..r(0x38c)..' scroll '..r(0x2e)..' screen '..r(0x2f)) end
 if frame==800 and (r(0x2e)==0 or r(0x38c)~=128) then print("FAIL camera midpoint crossing");emu.stop(1);return end
 if frame==1800 then
  local f=io.open((TEST_ROOT..'/analysis/scroll.png'),'wb');f:write(emu.takeScreenshot());f:close()
  if r(0x28)<1 then emu.stop(1) else emu.stop(0) end
 end
end,emu.eventType.endFrame)
