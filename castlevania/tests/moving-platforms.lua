-- Controlled player placement in natively initialized platform rooms.
-- Platform records, oscillation routines and velocities remain untouched;
-- real controller edges exercise riding, steering, takeoff, landing and edges.
local frame=0;local number=0;local phase='startup';local tick=0
local actor=nil;local stepped=false
local cases={}
for _,stage in ipairs({4,5,10}) do for power=0,2 do cases[#cases+1]={stage=stage,power=power,room=stage==10 and 0 or 1} end end
local rideChecks,jumps,landings,walkoffs=0,0,0,0
local leftCarry,rightCarry=0,0
local lastPX=nil;local originPX=nil;local relativeStart=nil;local launchY=nil
local root=(TEST_ROOT..'/')
local log=assert(io.open(root..'analysis/platform-fixtures.csv','w'));log:write('frame,case,phase,tick,actor,cam,x,y,px,py,pose,state,vx,carrylo,carryhi,support,relative\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function signed(n) return n>=128 and n-256 or n end
local function relative() return signed((r(0x38c)-r(0x38c+actor))%256) end
local function place(offset,fall)
 local x=r(0x38c+actor)+offset
 w(0x38c,x);w(0x3a8,0);w(0x40,x+r(0x2e));w(0x41,r(0x2f)+math.floor((x+r(0x2e))/256))
 w(0x3f,r(0x354+actor)-16-(fall and 8 or 0));w(0x354,r(0x3f));w(0x46c,fall and 1 or 0);w(0x514,fall and 1 or 0)
 w(0x434,0);w(0x47,0);w(0x5b,0);w(0x142,0);w(0x3c,4)
 for _,a in ipairs({0x6002,0x6003,0x6004,0x6005,0x6006,0x6070,0x6071,0x6072,0x6073,0x6074,0x6075,0x607f,0x606d,0x606e,0x606f}) do w(a,0) end
 if fall then w(0x6005,2);w(0x6070,2);w(0x607d,112) end
 w(0x6076,1);w(0x6077,1)
end
local function launch()
 number=number+1
 if not cases[number] then
  assert(leftCarry>50 and rightCarry>50,'Native platform oscillations must carry Mario in both directions')
  print('Moving platforms passed: '..#cases..' native stage/size cases; '..rideChecks..' grounded ride checks, '..jumps..' jumps, '..landings..' landings, '..walkoffs..' walk-offs; left/right carry '..leftCarry..'/'..rightCarry)
  emu.stop(0);phase='done';return
 end
 local c=cases[number];phase='loading';tick=0;actor=nil
 w(0x28,c.stage);w(0x600b,c.stage);w(0x46,c.room);w(0x48,0);w(0xe2,0);w(0x2d,0);w(0x2e,c.stage==10 and 128 or 0);w(0x2f,c.stage==5 and 1 or 0);w(0x18,5);w(0x19,0)
end
emu.addEventCallback(function()
 local joy={start=frame==120}
 if phase=='steerRight' or phase=='walkoff' then joy.right=true end
 if phase=='steerLeft' then joy.left=true end
 if phase=='jump' or phase=='reJump' then joy.a=true end
 emu.setInput(joy,0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if phase=='startup' or phase=='loading' or phase=='done' then return end
 stepped=true
 for x=3,22 do w(0x434+x,0);w(0x31c+x,0);w(0x60a0+x,0) end
 -- Isolate platform support from terrain and contact damage.
 for a=0x5a0,0x6ff do w(a,0) end
 w(0x600d,90);w(0x45,64)
end,emu.callbackType.exec,0x934c)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then launch() end
 if frame%500==0 then print('Platform fixture frame '..frame..' case '..number..' phase '..phase..' tick '..tick) end
 if phase=='loading' and r(0x18)==5 and r(0x19)==6 then
  for slot=23,26 do
   if r(0x434+slot)==1 and r(0x31c+slot)==0xc9 and not actor then actor=slot end
  end
  if actor then
   w(0x6001,cases[number].power);place(0,false)
   phase='ride';tick=0;originPX=r(0x38c+actor);lastPX=originPX;stepped=false
  end
 end
 if stepped then
  stepped=false;tick=tick+1
  local px=r(0x38c+actor)
  log:write(string.format('%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,number,phase,tick,actor,r(0x2e)+256*r(0x2f),r(0x38c),r(0x3f),px,r(0x354+actor),r(0x31c+actor),r(0x46c),signed(r(0x6071)),r(0x606e),r(0x606f),r(0x606d),relative()))
  log:flush()
  local delta=signed((px-lastPX)%256)
  if delta<0 then leftCarry=leftCarry+1 elseif delta>0 then rightCarry=rightCarry+1 end
  lastPX=px
  if phase=='ride' then
   assert(r(0x46c)==0 and r(0x6070)==0,'Platform must remain grounded: case '..number..' tick '..tick..' action '..r(0x46c))
   assert(math.abs(relative())<=1 and r(0x6071)==0,'Neutral Mario must follow native carry without acquiring sliding momentum')
   assert(r(0x3f)==r(0x354+actor)-16,'Mario feet must follow the native platform top')
   rideChecks=rideChecks+1
   if tick==160 then
    assert(math.abs(signed((px-originPX)%256))>3,'Native platform must actually move during the fixture')
    phase='steerRight';tick=0;relativeStart=relative()
   end
  elseif phase=='steerRight' then
   assert(r(0x46c)==0,'Steering right must retain platform support')
   if tick==12 then
    assert(signed(r(0x6071))>0 and relative()>relativeStart,'Right input must move Mario independently of platform carry')
    phase='steerLeft';tick=0
   end
  elseif phase=='steerLeft' then
   assert(r(0x46c)==0,'Reversing on a platform must retain support')
   if tick==16 then
    assert(signed(r(0x6071))<0,'Left input must reverse SMB velocity while riding')
    phase='brake';tick=0
   end
  elseif phase=='brake' then
   assert(r(0x46c)==0,'Neutral ground friction must keep Mario on the platform: case '..number..' tick '..tick..' relative '..relative())
   if tick==25 then
    assert(r(0x6071)==0,'Neutral riding must use SMB ground friction')
    phase='jump';tick=0;launchY=r(0x3f)
   end
  elseif phase=='jump' or phase=='reJump' then
   assert(r(0x46c)==1 and signed(r(0x6005))<0 and r(0x3f)<launchY,'Fresh A must take off and keep rising without platform snapping')
   assert(r(0x606d)==0 and r(0x142)&4==0,'Mario must detach on the first takeoff update')
   assert(r(0x606e)==0 and r(0x606f)==0,'Takeoff must not retain platform velocity')
   if tick==6 then
    jumps=jumps+1
    if phase=='jump' then place(0,true);phase='land';tick=0
    else
     place(19,false);w(0x6071,24);w(0x6073,24)
     phase='walkoff';tick=0
    end
   end
  elseif phase=='land' then
   if r(0x46c)==0 then
    assert(math.abs(relative())<=1 and r(0x3f)==r(0x354+actor)-16,'Descending Mario must land on the actual moving platform')
    assert(r(0x6005)==0 and r(0x6070)==0,'Platform landing must reset SMB vertical motion')
    landings=landings+1;phase='release';tick=0
   end
   assert(tick<12,'Descending platform landing timeout')
  elseif phase=='release' then
   assert(r(0x46c)==0,'Landing must remain stable until the next jump')
   if tick==3 then phase='reJump';tick=0;launchY=r(0x3f) end
  elseif phase=='walkoff' then
   if r(0x46c)==1 then
    assert(r(0x6070)==2,'Walking off the platform must enter normal SMB falling state')
    walkoffs=walkoffs+1
    print('Native platform case '..number..': stage '..cases[number].stage..', size '..cases[number].power..' passed')
    launch()
   else assert(tick<10,'Mario must be able to walk off a moving platform') end
  end
 end
 assert(frame<6500,'Native platform fixture timeout')
end,emu.eventType.endFrame)
