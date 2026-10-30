-- Read-only missed-vblank counters attached to the fresh controller route.
-- Keep busy first-room updates below a 1% missed-vblank budget.
local active=0
local missed=0
local outsideMissed=0
local reported=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addMemoryCallback(function()
 if r(0x18)==5 then
  if r(0x28)==1 then missed=missed+1 end
  if r(0x28)==0 then outsideMissed=outsideMissed+1 end
 end
end,emu.callbackType.exec,0xc0c0)
emu.addMemoryCallback(function()
 if r(0x18)==5 and r(0x28)==1 then active=active+1 end
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function()
 if r(0x28)==2 and r(0x18)==5 and r(0x19)==6 and not reported then
  assert(active>800,'Performance route must exercise the full first room')
  assert(outsideMissed==0,'Exterior route must maintain one update per vblank')
  assert(missed*100<=active,'First-room missed-vblank budget: '..missed..' / '..active)
  print('Performance budget passed: '..missed..' missed vblanks across '..active..' first-room updates; exterior misses '..outsideMissed)
  local file=assert(io.open((TEST_ROOT..'/analysis/performance-budget.json'),'w'))
  file:write(string.format('{"room_updates":%d,"missed_vblanks":%d,"exterior_missed_vblanks":%d,"maximum_percent":1,"passed":true}',active,missed,outsideMissed));file:close()
  reported=true
 end
end,emu.eventType.endFrame)
PLAYTHROUGH_LOG_TAG='performance-route'
dofile((TEST_ROOT..'/tests/playthrough.lua'))
