-- Native first-room ladder geometry, original grab/climb/fire/drop dispatch.
local f=0
local entered=nil
local seeded=false
local climbs=0
local shot=false
local minY=255
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()if r(0x29)==13 then w(0x2a,5)end end,emu.callbackType.exec,N.stage_select_loop)
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,up=t>=102 and t<190,b=t==150,a=t==190,left=t>=190 and t<220});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x29)~=14 then return end
 if not entered then entered=f;assert(r(0x2a)==7,'Crash Man native room')end
 for i=16,31 do w(0x420+i,0)end
 local t=f-entered
 if t==100 then
  -- Legal midair position on the real ladder, as reached by jumping beside
  -- the overhead platform. Keep native collision/cache/room data untouched.
  w(0x460,120);w(0x440,0);w(0x480,0);w(0x4a0,116);w(0x4c0,0);w(0xf9,0)
  w(0x2c,3);w(H.M_STATE,2);w(H.M_VY,1);w(H.M_VY_FRAC,0);w(H.M_SMB_X_SPEED,0);w(H.M_SMB_X_FORCE,0)
  seeded=true
 end
end,emu.callbackType.exec,H.Motion)
emu.addMemoryCallback(function()if entered and f-entered>=140 then shot=true end end,emu.callbackType.exec,H.FireSpawn)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<1800,'stage entry');return end
 local t=f-entered
 if t>105 and t<189 and (r(0x2c)==9 or r(0x2c)==10)then
  climbs=climbs+1;minY=math.min(minY,r(0x4a0));assert(r(0x701a)==1,'native ladder owns motion')
  assert(r(H.M_POSE)==7 or r(H.M_POSE)==8,'SMB climbing frames')
 end
 if t==165 then local out=assert(io.open(TEST_ROOT..'/build/ladder.png','wb'));out:write(emu.takeScreenshot());out:close()end
 if t==250 then
  assert(seeded and climbs>=20 and minY<106,'native ladder grab and upward movement')
  assert(shot,'can fire while climbing')
  assert(r(0x2c)>=3 and r(0x2c)<9 and r(0x701a)==0,'drop restores normal Mario control')
  print('PASS native ladder: '..climbs..' climbing updates, Mario art, firing, drop and control handoff')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
