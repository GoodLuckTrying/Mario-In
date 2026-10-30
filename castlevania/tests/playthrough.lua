-- Fresh boot, controller input only. RAM is read for routing and assertions.
local frame=0
local route=dofile((TEST_ROOT..'/tests/route-prefix.lua'))
local door=false
local heartBefore=nil
local heartFrame=nil
local hudChecked=false
local jumpUntil=0
local logTag=PLAYTHROUGH_LOG_TAG or 'playthrough'
local log=assert(io.open((TEST_ROOT..'/analysis/')..logTag..'.csv','w'))
log:write('frame,mode,stage,world,y,action,power,health,hearts,bumps,pickups,stomps,firehits,whiphits\n')
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
 local up=false
 if frame>700 and r(0x6000)==0x4D and stage==1 and r(0x18)==5 then
  if r(0x6047)<3 then
   right=world<131
   a=world>=145 and math.abs(vx())<0.15
   b=frame%30==0
  else
   right=true
   if world<900 and r(0x46c)==0 then
    local threat=false
    for x=3,19 do
     local ai=r(0x434+x)
     local dx=r(0x38c+x)-r(0x38c)
     if r(0x300+x)==0 and ai>0 and ai<0x28 and ai~=4 and ai~=5 and dx>0 and dx<55 and r(0x354+x)>=r(0x3f)-12 then threat=true end
    end
    if threat or r(0x142)%2==1 then jumpUntil=frame+25 end
   end
   a=frame<jumpUntil
   b=frame%20~=19
   up=world>=1200
   if up then b=false end -- Climb the actual stairs without throwing subweapons.
  end
 end
 emu.setInput({start=frame==120,right=right,a=a,b=b,up=up},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame>700 and r(0x6000)==0x4D and r(0x28)==1 and not heartBefore then heartBefore=r(0x71) end
 if heartBefore and r(0x28)==1 and r(0x71)>heartBefore and not heartFrame then heartFrame=frame end
 if heartFrame and not hudChecked and frame>=heartFrame+10 then
  assert(emu.read(0x2077,emu.memType.nesPpuDebug)==0xD0+math.floor(r(0x71)/10),'Controller pickup HUD tens')
  assert(emu.read(0x2078,emu.memType.nesPpuDebug)==0xD0+r(0x71)%10,'Controller pickup HUD ones')
  hudChecked=true
 end
 if frame>=700 then log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,r(0x18),r(0x28),r(0x40)+256*r(0x41),r(0x3f),r(0x46c),r(0x6001),r(0x45),r(0x71),r(0x6044),r(0x6047),r(0x6045),r(0x6046),r(0x603f))) end
 if r(0x18)==8 then door=true end
 if frame%300==0 then print('frame '..frame..' stage '..r(0x28)..' mode '..r(0x18)..' world '..r(0x40)+256*r(0x41)..' power '..r(0x6001)..' pickups '..r(0x6047)..' hearts '..r(0x71)) end
 if r(0x45)==0 and frame>700 then
  local f=assert(io.open((TEST_ROOT..'/analysis/')..logTag..'-failed.png','wb'));f:write(emu.takeScreenshot());f:close()
  print('FAIL controller replay died at world '..r(0x40)+256*r(0x41));log:close();emu.stop(1);return
 end
 if r(0x28)==2 and r(0x18)==5 and r(0x19)==6 and door then
  local ok=r(0x6044)==0 and r(0x603f)>=2 and r(0x6047)>=3 and heartBefore and r(0x71)>heartBefore and hudChecked
  print('Controller-only route: bumps '..r(0x6044)..', pickups '..r(0x6047)..', hearts '..r(0x71)..', fire hits '..r(0x6046)..', stomps '..r(0x6045)..', whip hits '..r(0x603f)..', health '..r(0x45))
  local f=assert(io.open((TEST_ROOT..'/analysis/')..logTag..'-door.png','wb'));f:write(emu.takeScreenshot());f:close()
  log:close();emu.stop(ok and 0 or 1);return
 end
 if frame==4000 then print('FAIL controller route timeout');log:close();emu.stop(1) end
end,emu.eventType.endFrame)
