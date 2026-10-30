-- Fresh boot and controller input only: small Mario fights an original zombie.
local frame=0
local approach=0
local enemy=nil
local damaged=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function vx() local n=r(0x6003);return (n>=128 and n-256 or n)+r(0x6002)/256 end
emu.addEventCallback(function()
 local stage=r(0x28)
 local world=r(0x40)+256*r(0x41)
 local right=frame>=710 and stage==0
 local b=right
 local left=false
 if stage==1 and r(0x18)==5 then
  if approach==0 and world>=125 then approach=1 end
  right=approach==0
  if approach==1 then
   left=vx()>0
   if vx()<=0 then approach=2 end
  elseif approach==2 then
   b=frame%30==0
  end
 end
 emu.setInput({start=frame==120,right=right,left=left,b=b},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x28)==1 and r(0x603e)==12 and r(0x0d)==6 then
  local actor=r(0x4e)
  if r(0x434+actor)==1 then enemy=actor end
 end
end,emu.callbackType.exec,0xe573)
emu.addMemoryCallback(function()
 if enemy then
  assert(r(0x434+enemy)~=1,'Whip must invoke the native zombie death handler')
  damaged=true
 end
end,emu.callbackType.exec,0xe8f0)
emu.addEventCallback(function()
 frame=frame+1
 if frame%300==0 then print('Whip route frame '..frame..' stage '..r(0x28)..' world '..r(0x40)+256*r(0x41)..' power '..r(0x6001)..' hits '..r(0x603f)) end
 if frame>710 and r(0x603f)>0 and damaged then
  assert(r(0x28)==1 and r(0x6001)==0 and r(0x6044)==0,'Small Mario must whip a native enemy without upgrades or candle bumps')
  assert(r(0x6020)==0 and r(0x6021)==0,'This controller route must use only the whip')
  assert(r(0x6045)==0 and r(0x6046)==0,'No stomp or fireball may damage the enemy')
  local f=assert(io.open((TEST_ROOT..'/analysis/whip-route.png'),'wb'));f:write(emu.takeScreenshot());f:close()
  print('Controller-only small whip native zombie destruction passed at frame '..frame)
  emu.stop(0)
 end
 if frame>710 and r(0x45)==0 then print('FAIL whip route died');emu.stop(1) end
 if frame==2200 then print('FAIL whip route timeout');emu.stop(1) end
end,emu.eventType.endFrame)
