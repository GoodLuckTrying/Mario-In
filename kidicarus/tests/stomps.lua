-- Real descending movement and native enemy updates; no collision callback
-- rewrites Mario or the enemy to manufacture a stomp.
local f=0
local seeded=false
local bounced=false
local defeated=false
local secondDefeated=false
local power=POWER or 0
local base=REAPER and 0x760 or 0x7C0
local flags=REAPER and 0x41 or 0x11
local stride=REAPER and 16 or 8
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=f==120 or f==200},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=600 and not seeded then
  seeded=true
  for a=0x500,0x6DF do w(a,0) end
  for x=0,15 do w(0x5C0+x,0x50);w(0x6B0+x,0x50) end
  for a=0x761,0x7F1,8 do w(a,0) end
  w(0xFD,0);w(0x6804,power);w(0x723,144);w(0x720,144);w(0x721,0x80)
  w(0x6805,2);w(0x6818,3);w(0x6819,0);w(0x6817,0);w(0x681B,0x70);w(0x681A,0x70)
  w(0x682A,0);w(0x682B,0);w(0x682C,0);w(0x6835,0);w(0x6806,0);w(0x6807,0);w(0x6808,0);w(0x3E,0)
  w(base+1,flags);w(base,176);w(base+3,PAIR and 136 or 144+(OFFSET or 0));w(base+2,0);w(base+4,0);w(base+5,0);w(base+7,1);w(base+8,0)
  if PAIR then
   local b=base+stride
   w(b+1,flags);w(b,176);w(b+3,152);w(b+2,0);w(b+4,0);w(b+5,0);w(b+7,1);w(b+8,0)
  end
 end
end,emu.callbackType.exec,0xCBB6)
emu.addEventCallback(function()
 f=f+1
 if seeded then
  if TRACE and f<616 then print('crossing f='..f..' player='..r(0x723)..','..r(0x720)..' VY='..r(0x6818)..' enemy='..r(base+3)..','..r(base)..' flags='..r(base+1)) end
  if r(0x6818)>=128 then bounced=true end
  if r(base+1)~=flags then defeated=true end
  if PAIR and r(base+stride+1)~=flags then secondDefeated=true end
  assert(r(0x6804)==power and r(0x721)&0x40==0,'Landing on an enemy must preserve Mario')
 end
 if f>=625 then
  print('natural stomp power='..power..' bounce='..tostring(bounced)..' native defeat='..tostring(defeated)..' second='..tostring(secondDefeated))
  assert(seeded and bounced and defeated,'Natural downward crossing must bounce Mario and damage the native enemy')
  if PAIR then assert(secondDefeated,'Both adjacent enemies must receive their native stomp defeat') end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
