-- Controlled stale actor pose, equivalent to a ghost retained in a save state.
-- Keep Mario's AI-less custom sprite and native auxiliary sprites visible.
local frame=0
local player,auxiliary=false,false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame~=700 then return end
 for _,slot in ipairs({12,23}) do
  w(0x434+slot,0);w(0x31c+slot,0x31);w(0x300+slot,0)
  w(0x38c+slot,200);w(0x354+slot,100);w(0x450+slot,0)
 end
end,emu.callbackType.exec,0xcf1c)
emu.addMemoryCallback(function()
 if frame~=700 or r(0x27)~=0 then return end
 local slot=r(5)
 assert(slot~=12,'Stale inactive gameplay pose must not render')
 if slot==0 then player=true end
 if slot==23 then auxiliary=true end
end,emu.callbackType.exec,0x80d6)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then
  assert(r(0x434+12)==0 and r(0x31c+12)==0x31,'Fixture must retain the inactive pose throughout rendering')
  assert(player and auxiliary,'Player and native auxiliary sprites must remain visible without actor AI')
  print('Inactive sprite guard passed; player and native auxiliary rendering preserved')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
