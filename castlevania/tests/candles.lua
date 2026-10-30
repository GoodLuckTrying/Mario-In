local frame=0
local route=dofile((TEST_ROOT..'/tests/route-prefix.lua'))
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput(route(frame) or {},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame%150==0 and frame>=600 then
  print('frame '..frame..' stage '..r(0x28)..' player '..r(0x38c)..' power '..r(0x6001)..' pickups '..r(0x6047)..' whip '..r(0x603f))
  for x=3,22 do if r(0x434+x)>=0x28 or r(0x60a0+x)>0 then print('actor '..x..' ai '..r(0x434+x)..' x '..r(0x38c+x)..' y '..r(0x354+x)..' kind '..r(0x60a0+x)) end end
 end
 if r(0x6001)==2 and r(0x6047)>=2 then
  assert(r(0x6044)==0 and r(0x603f)>=2,'Upgrades must come from whip hits, without lamp bumps')
  local file=assert(io.open((TEST_ROOT..'/analysis/candles-whipped.png'),'wb'));file:write(emu.takeScreenshot());file:close()
  print('Controller-only mushroom and flower via whip passed at frame '..frame);emu.stop(0)
 end
 if frame==2200 then assert(false,'Upgrade controller replay timeout') end
end,emu.eventType.endFrame)
