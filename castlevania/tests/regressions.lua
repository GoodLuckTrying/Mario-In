local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local intro,stairs={},{}
local player=false
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 player=emu.getState()["cpu.x"]==0
end,emu.callbackType.exec,0x8086)
emu.addMemoryCallback(function()
 if not player then return end
 local ptr=r(8)+256*r(9)
 if r(0x6000)==0x4D and ptr>=0xBB10 then
  if r(0x18)==4 then intro[ptr]=true end
  if frame>=740 and frame<770 then stairs[ptr]=true end
 end
end,emu.callbackType.exec,0x80a5)
emu.addMemoryCallback(function()
 if frame==700 then
  -- Reuse a previously raised slot for a fresh two-piece floor candle.
  w(0x6001,255); w(0x6083,1); w(0x60e3,80)
  w(0x434+3,0x28); w(0x354+3,176); w(0x38c+3,r(0x38c)); w(0x300+3,0)
  w(0x46c,1); w(0x6005,255); w(0x6008,176); w(0x3f,164); w(0x354,164)
 elseif frame>=710 and frame<730 then
  -- Repeated heart pickups with a full counter must leave Fire Mario intact.
  w(0x71,99); w(0x434+3,4); w(0x60a3,3); w(0x60c3,100)
  w(0x38c+3,r(0x38c)); w(0x354+3,r(0x3f)); w(0x300+3,0)
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if frame>=740 and frame<770 then
  -- Exercise the native stair action, with no custom horizontal velocity.
  w(0x46c,4); w(0x6002,0); w(0x6003,0)
  w(0x354,176-math.floor((frame-740)/2)); w(0x3f,r(0x354))
 end
end,emu.callbackType.exec,0x8086)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then
  assert(r(0x6044)==0,'Jumping beneath a lamp must not break it')
  assert(r(0x437)==0x28 and r(0x357)==176 and r(0x60a3)==0,'Floor lamp must retain its native position and remain intact')
  assert(r(0x6001)==2,'Power must be capped at Fire Mario')
  print('No lamp bumping and power cap passed')
 end
 if frame==730 then assert(r(0x6001)==2 and r(0x71)==99,'Repeated hearts must not overflow'); print('Repeated heart pickups passed') end
 if frame==780 then
  local n=0; for _ in pairs(intro) do n=n+1 end
  print('Intro pose count: '..n)
  if n<3 then emu.stop(1); return end
  local m=0; for _ in pairs(stairs) do m=m+1 end
  print('Stair pose count: '..m)
  if m<3 then emu.stop(1); return end
  print('Intro and stair animation passed')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
