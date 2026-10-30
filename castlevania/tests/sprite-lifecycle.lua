-- Fresh boot and controller input only. Audit native slot reuse and every
-- dynamic OAM entry as small Mario grows and scrolls right, then back left.
local frame=0
local route=dofile((TEST_ROOT..'/tests/route-prefix.lua'))
local root=(TEST_ROOT..'/')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local used={}
local emptied={}
local candles={}
local renders,hiddenChecks,emptySlots,candleChecks=0,0,0,0
local rightScroll,leftScroll=0,0
local smallRenders,grownRenders=0,0
local lastCamera=nil
local rendering=false
local function active() return frame>=700 and r(0x18)==5 end
emu.addEventCallback(function()
 local prefix=route(frame)
 if prefix then emu.setInput(prefix,0);return end
 local stage=r(0x28)
 local world=r(0x40)+256*r(0x41)
 local right=frame>=710
 local left=false
 if stage==1 then
  if world>700 or frame>1700 then right=false;left=true end
 end
 emu.setInput({start=frame==120,right=right,left=left,b=frame%32<16,a=frame%180<26},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not active() then return end
 emptied[emu.getState()['cpu.x']]=true
end,emu.callbackType.exec,0xd285)
emu.addMemoryCallback(function()
 if not active() then return end
 for slot in pairs(emptied) do
  assert(r(0x434+slot)==0 and r(0x300+slot)~=0,'Empty spawn slot must retain its native hidden flag')
  assert(r(0x31c+slot)==0 and r(0x60a0+slot)==0 and r(0x60c0+slot)==0,'Empty spawn slot must clear its old pose and custom pickup metadata')
  emptySlots=emptySlots+1
 end
 emptied={}
 candles={}
 for slot=14,19 do
  if r(0x434+slot)>=0x28 and r(0x434+slot)<=0x2e then candles[slot]=r(0x38c+slot) end
 end
end,emu.callbackType.exec,0xcf05)
emu.addMemoryCallback(function()
 if not active() then return end
 for slot,x in pairs(candles) do
  if r(0x434+slot)>=0x28 and r(0x434+slot)<=0x2e then
   assert(r(0x38c+slot)==(x+r(0x49))%256,'Active candle must consume the camera movement once')
   candleChecks=candleChecks+1
  end
 end
end,emu.callbackType.exec,0xcf1c)
emu.addMemoryCallback(function()
 rendering=r(0x27)==0 and active()
 used={}
 if rendering and r(0x28)==1 then
  local camera=r(0x2e)+256*r(0x2f)
  if lastCamera then
   if camera>lastCamera then rightScroll=rightScroll+1 end
   if camera<lastCamera then leftScroll=leftScroll+1 end
  end
  lastCamera=camera
 end
end,emu.callbackType.exec,0x8052)
emu.addMemoryCallback(function()
 if not rendering then return end
 local slot=r(5)
 if slot>=3 and slot<=22 then
  assert(r(0x434+slot)~=0,'Inactive actor must never draw a stale sprite')
 end
end,emu.callbackType.exec,0x80d6)
local function allocation()
 if not rendering then return end
 local index=emu.getState()['cpu.x']
 assert(index>=0x44 and index%4==0 and not used[index],'Dynamic OAM allocations must be unique')
 used[index]=true
end
-- Native odd encoded-Y records use C5 to reuse the previous attributes.
emu.addMemoryCallback(allocation,emu.callbackType.exec,0x80f4)
emu.addMemoryCallback(allocation,emu.callbackType.exec,0x80c5)
emu.addMemoryCallback(function()
 if not rendering then return end
 renders=renders+1
 if r(0x6001)==0 then smallRenders=smallRenders+1 else grownRenders=grownRenders+1 end
 for index=0x44,0xfc,4 do
  if not used[index] then
   assert(r(0x200+index)==0xf4,'Unused OAM entry must be hidden after each render: frame '..frame..' slot '..index..' Y '..r(0x200+index)..' remaining '..r(7)..' cursor '..r(4)..' actor '..r(5))
   hiddenChecks=hiddenChecks+1
  end
 end
 rendering=false
end,emu.callbackType.exec,0x80c1)
emu.addEventCallback(function()
 frame=frame+1
 if frame%400==0 then print('Sprite lifecycle route frame '..frame..' stage '..r(0x28)..' world '..(r(0x40)+256*r(0x41))) end
 if frame==1800 then local f=assert(io.open(root..'analysis/sprite-lifecycle-backtrack.png','wb'));f:write(emu.takeScreenshot());f:close() end
 if frame==2400 then
  assert(r(0x28)==1 and r(0x6001)>0 and r(0x45)>16,'Healthy controller route must retain grown Mario under the low-health policy')
  assert(smallRenders>50 and grownRenders>500,'Controller route must audit OAM at both small and grown sizes')
  assert(rightScroll>100 and leftScroll>100 and emptySlots>5 and candleChecks>1000 and renders>1000,'Sprite route must cover both camera directions, native empty slots and active candles')
  print('Sprite lifecycle passed: '..renders..' renders, '..hiddenChecks..' unused OAM checks, '..emptySlots..' empty spawns, '..candleChecks..' active candle shifts; right/left scrolls '..rightScroll..'/'..leftScroll)
  print('Sprite size coverage: '..smallRenders..' small renders, '..grownRenders..' grown renders')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
