local f=0
local entered=nil
local steps=0
local minY=255
local maxY=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function save(name)local o=assert(io.open(TEST_ROOT..'/build/motion-'..name..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f<650 and f%120<3,
 a=(t>=40 and t<90)or(t>=160 and t<162),right=t>=230 and t<500,b=t>=360 and t<500});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not entered then entered=f;print('ENTER '..f..' x='..r(0x5af)..' y='..r(0x599))end
 steps=steps+1
 for x=1,16 do w(0x4f0+x,0)end
 w(0x4f0,r(0x4f0)&0xfe)
 minY=math.min(minY,r(0x599));maxY=math.max(maxY,r(0x599))
 if steps%20==0 then print('STEP '..steps..' t='..(f-entered)..' pos='..r(0x583)..':'..r(0x5af)..','..r(0x56d)..':'..r(0x599)..' state='..r(H.M_STATE)..' vy='..r(H.M_VY)..' task='..r(0)..' sp='..emu.getState()['cpu.sp'])end
end,emu.callbackType.exec,H.Step)
emu.addEventCallback(function()
 f=f+1
 if entered then
  local t=f-entered
  if t==100 or t==300 or t==500 then save(t)end
  if t==550 then print('PASS motion research '..steps..' steps; Y '..minY..'..'..maxY);emu.stop(0)end
 end
 assert(f<4000,'native player enters controller')
end,emu.eventType.endFrame)
