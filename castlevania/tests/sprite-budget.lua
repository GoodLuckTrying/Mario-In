-- Directed renderer saturation, including the exact-full cleanup boundary.
local frame,n,pending=0,0,false
local used={};local expected=0;local startCycle=0;local checks=0;local maximum=0
local interruptStart=nil;local interruptCycles=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function() frame=frame+1;assert(frame<900,'Sprite saturation timeout') end,emu.eventType.endFrame)
emu.addMemoryCallback(function()
 if frame<700 or r(0x27)~=0 then return end
 n=n+1
 if n>90 then print('Sprite saturation passed: '..checks..' allocations across under/full/overflow pools; maximum '..maximum..' cycles');emu.stop(0);return end
 pending=true;used={};startCycle=emu.getState()['cpu.cycleCount'];interruptCycles=0;interruptStart=nil
 local count=n%3==0 and 14 or n%3==1 and 15 or 20
 expected=math.min(47,2+count*3)
 w(0x6001,0);w(0x6013,0);w(0x600d,0);w(0x5b,0);w(0x603e,0);w(0x46c,0);w(0x6071,0);w(0x6062,0)
 w(0x6020,0);w(0x6021,0);w(0x300,0)
 for slot=3,27 do
  w(0x300+slot,slot<3+count and 0 or 128);w(0x434+slot,4);w(0x60a0+slot,0)
  w(0x31c+slot,7);w(0x338+slot,0);w(0x450+slot,0)
  w(0x38c+slot,32+slot*6);w(0x354+slot,112+slot)
 end
end,emu.callbackType.exec,0x8052)
local function allocation()
 if not pending or r(0x27)~=0 then return end
 local x=emu.getState()['cpu.x']
 assert(x>=0x44 and x%4==0 and not used[x],'Saturated renderer must neither overwrite HUD nor reuse an OAM entry')
 used[x]=true;checks=checks+1
end
emu.addMemoryCallback(allocation,emu.callbackType.exec,0x80f4)
emu.addMemoryCallback(allocation,emu.callbackType.exec,0x80c5)
-- A deliberately saturated fixture can overlap a native busy NMI. Measure
-- the renderer's own cost separately from that interrupt's music/raster work.
emu.addMemoryCallback(function() if pending then interruptStart=emu.getState()['cpu.cycleCount'] end end,emu.callbackType.exec,0xc052)
emu.addMemoryCallback(function()
 if pending and interruptStart then interruptCycles=interruptCycles+emu.getState()['cpu.cycleCount']-interruptStart;interruptStart=nil end
end,emu.callbackType.exec,0xc0bf)
emu.addMemoryCallback(function()
 if not pending then return end
 pending=false
 local count=0
 for x=0x44,0xfc,4 do
  if used[x] then count=count+1;assert(r(0x200+x)~=244,'Exact-full pool must retain its first sprite')
  else assert(r(0x200+x)==244,'Underfull pool must clear unused OAM') end
 end
 assert(count==expected,'Renderer must fill every available slot before stopping: '..count..' / '..expected)
 local cycles=emu.getState()['cpu.cycleCount']-startCycle-interruptCycles
 maximum=math.max(maximum,cycles)
 assert(cycles<12000,'Saturated renderer must fit its 12K CPU budget: '..cycles..' count '..count)
end,emu.callbackType.exec,0xc0af)
