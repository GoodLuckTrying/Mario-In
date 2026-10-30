local f=0;local entered=nil;local peak=0;local base=0;local maxSpeed=0;local stopped=nil;local jumps=0;local duck=false;local updates=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%60<2,a=t>=5 and t<30,right=t>=90 and t<180,b=t>=90 and t<180,down=t>=300 and t<330})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x10)~=11 then return end
 for i=0,5 do w(0x650+i*16,0)end
 if not entered then
  if r(0x7d31)==0 or r(H.M_STATE)~=0 or r(0x62)&31>=9 then return end
  entered=f
 end
 updates=updates+1
 local t=f-entered
 if t==0 then base=r(0x64)end
 peak=math.max(peak,base-r(0x64));maxSpeed=math.max(maxSpeed,r(H.M_SMB_X_ABS))
 if r(H.M_STATE)~=0 then jumps=jumps+1 end
 if t>=250 and t<280 then
  assert(r(H.M_SMB_X_SPEED)==0,'native ground release brakes to rest')
  local world=(r(0x63)+r(0x0c))&255
  stopped=stopped or world;assert(world==stopped,'no persistent ground slide in world coordinates')
 end
 if t>=310 and t<325 and r(H.M_POSE)==6 then duck=true end
end,emu.callbackType.exec,0xF28D)
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
