-- Fresh boot and controller input only, including original power-up collection.
local frame=0
local route=dofile((TEST_ROOT..'/tests/route-prefix.lua'))
local jumpUntil=0
local approach=0
local brokenAt=nil
local brickPpu=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function vx() local n=r(0x6003);return (n>=128 and n-256 or n)+r(0x6002)/256 end
emu.addEventCallback(function()
 local prefix=route(frame)
 if prefix then emu.setInput(prefix,0);return end
 local stage=r(0x28)
 local world=r(0x40)+256*r(0x41)
 local right=(frame>=710 and frame<747) or (frame>=850 and frame<939) or (frame>=1400 and stage==0)
 local a=(frame>=790 and frame<820) or (frame>=990 and frame<1020)
 local b=frame==1140 or (frame>=1400 and stage==0)
 local left=false
 if frame>700 and r(0x6000)==0x4d and stage==1 and r(0x18)==5 then
  if r(0x6047)<3 then
   right=world<131
   a=world>=145 and math.abs(vx())<0.15
   b=frame%30==0
  else
   if approach==0 and world>=1040 then approach=1 end
   right=approach==0
   if r(0x46c)==0 then
    local threat=false
    for x=3,19 do
     local ai=r(0x434+x)
     local dx=r(0x38c+x)-r(0x38c)
     if r(0x300+x)==0 and ai>0 and ai<0x28 and ai~=4 and ai~=5 and dx>0 and dx<55 and r(0x354+x)>=r(0x3f)-12 then threat=true end
    end
    if world<900 and (threat or r(0x142)%2==1) then jumpUntil=frame+25 end
   end
   a=frame<jumpUntil
   b=frame%20~=19
   if approach==1 then
    left=vx()>0
    a=false;b=false
    if vx()<=0 then approach=2 end
   elseif approach==2 then
    a=frame%75<25
    b=frame%20==0
   end
  end
 end
 emu.setInput({start=frame==120,right=right,left=left,a=a,b=b},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame>700 and r(0x27)==6 and r(0x28)==1 and r(0x6038)>0 and not brickPpu then
  brickPpu=r(0x09)*256+r(0x08)
  for _,offset in ipairs({0,1,32,33}) do assert(emu.read(brickPpu+offset,emu.memType.nesPpuDebug)~=0,'Actual authored brick must initially be visible') end
 end
end,emu.callbackType.exec,0xa98f)
emu.addEventCallback(function()
 frame=frame+1
 if frame%400==0 then print('frame '..frame..' world '..r(0x40)+256*r(0x41)..' stage '..r(0x28)..' y '..r(0x3f)..' brick '..r(0x6038)) end
 if frame>700 and r(0x6000)==0x4d and r(0x6038)>0 and not brokenAt then
  assert(r(0x28)==1 and r(0x146)%2==1 and r(0x6001)==2,'First indoor wall must break with naturally collected fire power')
  brokenAt=frame
 end
 if brokenAt and frame==brokenAt+12 then
  assert(brickPpu,'Native background edit must run')
  for _,offset in ipairs({0,1,32,33}) do assert(emu.read(brickPpu+offset,emu.memType.nesPpuDebug)==0,'Broken brick must disappear from the actual background') end
  local f=assert(io.open((TEST_ROOT..'/analysis/brick-route.png'),'wb'));f:write(emu.takeScreenshot());f:close()
  print('Controller-only B attack brick destruction passed at frame '..frame)
  emu.stop(0)
 end
 if frame>700 and r(0x45)==0 then print('FAIL brick route died');emu.stop(1) end
 if frame==3000 then
  local f=assert(io.open((TEST_ROOT..'/analysis/brick-route-stuck.png'),'wb'));f:write(emu.takeScreenshot());f:close()
  print('FAIL brick route timeout power '..r(0x6001)..' action '..r(0x46c));emu.stop(1)
 end
end,emu.eventType.endFrame)
