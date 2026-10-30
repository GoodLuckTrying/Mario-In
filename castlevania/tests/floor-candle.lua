local frame=0
local heartBefore=nil
local pickupsBefore=nil
local route=dofile((TEST_ROOT..'/tests/route-prefix.lua'))
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput(route(frame) or {},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if r(0x28)==1 and not heartBefore then heartBefore=r(0x71);pickupsBefore=r(0x6047) end
 if r(0x28)==1 and pickupsBefore and r(0x6047)>pickupsBefore then
  assert(r(0x6001)==2 and r(0x6044)==0,'Lamp break must preserve Fire Mario without bumping')
  assert(heartBefore and r(0x71)>heartBefore,'First indoor floor lamp must yield collectible hearts')
  print('First-room floor lamp controller weapon replay passed at frame '..frame);emu.stop(0)
 end
 if frame==2300 then assert(false,'Floor lamp controller replay timeout') end
end,emu.eventType.endFrame)
