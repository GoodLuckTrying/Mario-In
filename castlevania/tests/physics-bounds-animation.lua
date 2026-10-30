-- Directed visual-state fixtures. Native renderer chooses every pose itself.
local frame,n,pending=0,0,false
local cases={}
for power=0,2 do
 for walk=0,2 do cases[#cases+1]={power=power,state=2,walk=walk,crouch=0} end
 cases[#cases+1]={power=power,state=1,walk=2,crouch=0}
end
for power=0,2 do for crouch=0,1 do
 cases[#cases+1]={power=power,state=0,walk=0,crouch=crouch,bounds=true}
 cases[#cases+1]={power=power,state=1,walk=0,crouch=crouch,bounds=true}
end end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() frame=frame+1 end,emu.eventType.endFrame)
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
-- UpdateBodySize runs before the sprite renderer, once per normal player update.
emu.addMemoryCallback(function()
 if frame<700 or pending then return end
 n=n+1;if not cases[n] then print('Bounds/animation passed: '..#cases..' cases');emu.stop(0);return end
 local c=cases[n];pending=true
 w(0x6001,c.power);w(0x6013,c.crouch)
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if not pending or r(0x27)~=0 then return end
 local c=cases[n]
 local tall=c.power>0 and c.crouch==0
 assert((r(0x6014)~=0)==tall,'Body height must follow form and crouching')
 assert(r(0x5e)==(c.power>0 and 6 or 5),'Hurtbox X radius must match SMB')
 assert(r(0x5f)==(tall and 12 or 6),'Hurtbox Y radius must match SMB')
 w(0x6070,c.state);w(0x46c,1);w(0x6069,c.walk)
 w(0x600d,0);w(0x5b,0);w(0x603e,0);w(0x300,0)
end,emu.callbackType.exec,0x8052)
emu.addMemoryCallback(function()
 if not pending or r(0x27)~=0 or r(5)~=0 then return end
 local c=cases[n]
 if not c.bounds then
  local index=c.state==1 and (c.power==0 and 7 or 8) or (c.power==0 and 1 or 4)+c.walk
  assert(r(8)+256*r(9)==AUDIT_POINTERS[index],'Walk-off must retain walk pose; deliberate jumps must use jump pose')
 end
 pending=false
end,emu.callbackType.exec,0x80a5)
emu.addEventCallback(function() assert(frame<900,'Bounds/animation fixture timeout') end,emu.eventType.endFrame)
