-- Controller-only cold-boot replay; no player or map RAM writes.
local f=0
local booted=false
local phase=0
local t=0
local picked=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function nextphase(p)phase=p;t=0;print('PHASE '..p..' at '..f..' x '..r(0x4f0)..' y '..r(0x510)) end
emu.addEventCallback(function()
 local pad={start=not booted and f%90<4}
 local x=r(0x4f0);local y=r(0x510);local v=r(0x6806);local state=r(0x54)
 if f>=650 then
  if phase==0 then nextphase(1) end
  if phase==1 then
   pad.right=true;pad.b=true
   if x>=88 and state==0 then nextphase(2) end
  elseif phase==2 then
   pad.left=true;pad.b=true
   if v==0 or v>=128 then nextphase(3) end
  elseif phase==3 then
   pad.a=t<30
   if t>20 and state==0 and y==116 then nextphase(4) end
  elseif phase==4 then if t>=10 then nextphase(5) end
  elseif phase==5 then
   pad.a=t<30;pad.left=true
   if t>20 and state==0 and y==52 then nextphase(6) end
  elseif phase==6 then if t>=10 and x==72 and v==0 then nextphase(7) end
  elseif phase==7 then pad.b=t<8 end
 end
 setPad(0,pad);setPad(1,{})
 t=t+1
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if phase==7 and r(0x56)>=0x82 then picked=true end
 if f==1100 then
  local o=assert(io.open(TEST_ROOT..'/build/upper-route.png','wb'));o:write(emu.takeScreenshot());o:close()
  assert(picked,'Controller-only route must reach the high platform and pick up a box from its right side')
  print('PASS controller-only upper-platform pickup');emu.stop(0)
 end
end,emu.eventType.endFrame)


