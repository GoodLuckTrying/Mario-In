local f=0;local entered=nil;local peak=0;local base=0;local maxSpeed=0;local stopped=nil;local jumps=0;local duck=false;local updates=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%60<2,a=t>=5 and t<30,right=t>=90 and t<180,b=t>=90 and t<180,down=t>=300 and t<330})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
 if not entered then
  if r(H.M_STATE)~=0 or r(0x522)&0xA0==0 then return end
  entered=f
 end
 updates=updates+1
 local t=f-entered
 if t==0 then base=r(0x4f2)end
 peak=math.max(peak,base-r(0x4f2));maxSpeed=math.max(maxSpeed,r(H.M_SMB_X_ABS))
 if r(H.M_STATE)~=0 then jumps=jumps+1 end
 if t>=250 and t<280 then
  assert(r(H.M_SMB_X_SPEED)==0,'native ground release brakes to rest')
  stopped=stopped or r(0x512);assert(r(0x512)==stopped,'no persistent ground slide')
 end
 if t>=310 and t<325 and r(H.M_POSE)==5 then duck=true end
end,emu.callbackType.exec,0x9B9A)
emu.addEventCallback(function()
 f=f+1
 if entered and f-entered>=400 then
  assert(peak>=45 and peak<=80,'Mario jump rise '..peak)
  assert(maxSpeed==40,'SMB running limit reached: '..maxSpeed)
  assert(jumps>20 and duck,'jump and crouch poses exercised')
  assert(updates>300,'native update cadence exercised')
  print('PASS physical controls: jump '..peak..' pixels, run/brake/crouch, '..updates..' native updates');emu.stop(0)
 end
 assert(f<2000,'bounded movement replay')
end,emu.eventType.endFrame)
