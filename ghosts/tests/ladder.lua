local f=0
local entered=nil
local seeded=nil
local nativeTicks=0
local poses={}
local lowest=255
local highest=0
local regained=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=seeded and f-seeded or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,up=seeded and t>=6 and t<210,a=seeded and t>=225 and t<250});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f
 for i=1,16 do w(0x4f0+i,0)end
 if not seeded and f-entered>60 then
  w(0x5af,216);w(0x583,2);w(0x599,184);w(0x56d,0);w(0x509,184);w(0x554,96);w(0x64,120);w(0x65,2)
  w(H.M_STATE,0);w(H.M_VY,0);w(H.M_SMB_X_SPEED,0);w(H.M_SMB_X_FORCE,0);w(0x5db,0);w(0x5c5,0)
  seeded=f
 elseif seeded and f-seeded>150 then regained=true end
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 if seeded then
  nativeTicks=nativeTicks+1;lowest=math.min(lowest,r(0x599));highest=math.max(highest,r(0x599))
  for i=1,16 do w(0x4f0+i,0)end
 end
end,emu.callbackType.exec,0xdcb2)
emu.addMemoryCallback(function()if seeded then poses[r(H.M_WANT)]=true end end,emu.callbackType.exec,H.DrawMario)
emu.addEventCallback(function()
 f=f+1
 if seeded and f-seeded==280 then
  assert(nativeTicks>10 and lowest<150,'native ladder climb is retained; ticks '..nativeTicks..' min '..lowest)
  local p='';for k in pairs(poses)do p=p..k..',' end;assert(poses[8] and poses[9],'both SMB climbing poses are used; seen '..p..' native '..r(H.M_NATIVE)..' state '..r(0x61d))
  assert(regained and r(H.M_NATIVE)==0,'normal Mario control resumes after ladder exit')
  print('PASS real stage-1 ladder tiles, native climbing, two climbing frames, exit and Mario jump/control handoff');emu.stop(0)
 end
 assert(f<2500,'ladder test completes')
end,emu.eventType.endFrame)
