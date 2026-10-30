dofile(TEST_ROOT..'/tests/graphics_oracle.lua')
local f=0
local entered=nil
local seeded=nil
local grounded=0
local carried=0
local jumped=0
local supportX=nil
local platformUpdate=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local kind=KIND or 13
local form=FORM or 0
emu.addEventCallback(function()
 local t=seeded and f-seeded or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,a=t>=75 and t<100,right=t>=150 and t<200,b=t>=150 and t<200})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f
 if seeded and f-seeded<70 and r(0x4f0)&0x10~=0 then
  assert(r(H.M_STATE)==0,'native moving-platform contact must establish grounded Mario')
  assert(r(H.M_VY)==0 and r(H.M_VY_FRAC)==0,'moving-platform landing clears fall speed and fraction')
  grounded=grounded+1
 end
 if seeded and f-seeded>=75 and f-seeded<115 and r(H.M_VY)>=128 then jumped=jumped+1 end
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 if not entered or seeded or f-entered<60 then return end
 for x=1,21 do w(0x4f0+x,0)end
 w(0x4f0,0x80|form);w(0x61d,0);w(H.M_FORM,form);w(H.M_STATE,1);w(H.M_VY,2);w(H.M_VY_FRAC,0);w(H.M_SMB_X_SPEED,0);w(H.M_SMB_X_FORCE,0)
 w(0x599,kind==12 and 144 or 100);w(0x56d,0);w(0x5af,112);w(0x583,0);w(0x5db,0);w(0x5c5,0);w(0x509,kind==12 and 144 or 100);w(0x554,112)
 w(0x4f1,0x80);w(0x632,kind);w(0x648,0);w(0x61e,0);w(0x608,0);w(0x65e,0);w(0x5f2,4)
 w(0x59a,kind==12 and 160 or 112);w(0x56e,0);w(0x5b0,112);w(0x584,0);w(0x5dc,0);w(0x5c6,0);w(0x50a,kind==12 and 160 or 112);w(0x555,112)
 seeded=f;supportX=r(0x5af)
end,emu.callbackType.exec,0x9cc8)
emu.addMemoryCallback(function()
 if not platformUpdate then return end
 platformUpdate=false
 if not seeded then return end
 local t=f-seeded
 if t<70 then
  carried=carried+1
  assert(r(H.M_STATE)==0 and r(H.M_VY)==0,'native platform carry keeps Mario grounded')
  assert(r(H.M_POSE)~=4 and r(H.M_POSE)~=16,'standing on platform must not retain falling pose')
  local dy=(r(0x59a)-r(0x599))&255
  assert(dy==12 or(kind==12 and dy>=14 and dy<=18),'Mario feet align with the native platform surface/carry prediction; gap '..dy)
 end
end,emu.callbackType.exec,N.PlayerPosition)
emu.addMemoryCallback(function()platformUpdate=true end,emu.callbackType.exec,H.PlatformGround)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2000,'platform fixture enters');return end
 if seeded and f-seeded==230 then
  assert(grounded>12 and carried>12,'real native moving platform repeatedly supports Mario')
  assert(jumped>4,'Mario can jump away from a moving platform; updates '..jumped..' grounded '..grounded..' carried '..carried)
  local o=assert(io.open(TEST_ROOT..'/build/platform-'..kind..'-'..form..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  assertMarioGraphics()
  print('PASS moving platform '..kind..' form '..form..', native carry '..carried..', grounded checks '..grounded..', jump updates '..jumped)
  emu.stop(0)
 end
 assert(f-entered<1000,'platform fixture completes')
end,emu.eventType.endFrame)
