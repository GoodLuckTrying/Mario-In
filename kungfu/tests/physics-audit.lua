-- Measure the actual game's short/held jump arcs through physical Up input.
local f=0;local index=1;local tick=0;local armed=false;local ret=nil
local cases={}
for power=0,2 do for _,hold in ipairs({1,25})do cases[#cases+1]={power=power,hold=hold}end end
local peak=135
local rows={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local c=cases[index]
 setPad(0,{start=f>=180 and f<190,up=f>=800 and c and tick<c.hold});setPad(1,{})
end,emu.eventType.inputPolled)
local function after()
 if not armed then return end
 armed=false;peak=math.min(peak,r(0x7c04));tick=tick+1
 if tick==100 then
  local c=cases[index];local rise=135-peak
  assert(rise==(c.hold==1 and 24 or 64),'live Kung Fu jump must reproduce the exact SMB1 arc')
  assert(r(0x7c04)==135 and r(0x7c08)==0,'native floor return')
  print('MEASURE P'..r(0x55)..' power'..c.power..' hold'..c.hold..' rise'..rise..' SMB1 '..(c.hold==1 and 24 or 64))
  rows[#rows+1]={power=c.power,hold=c.hold,rise=rise}
  index=index+1;tick=0;peak=135
  if index>#cases then print('PASS 600 live Kung Fu jump updates match SMB1 apexes in all three forms');emu.stop(0)end
 end
end
emu.addMemoryCallback(function()
 if f<800 or index>#cases then return end
 if not ret then
  local sp=emu.getState()['cpu.sp'];ret=r(0x100+sp+1)+256*r(0x100+sp+2)+1
  emu.addMemoryCallback(after,emu.callbackType.exec,ret)
 end
 for i=0,5 do w(0x80+i,0)end
 w(0x373,0);w(0x374,0);w(0x7c01,255);w(0x4a6,48)
 if tick==0 then
  for i=0,0x1f do w(0x7d00+i,0)end
  for i=0,0xf do w(0x7c00+i,0)end
  w(0x7c00,cases[index].power);w(0x7c01,255);w(0x7c02,1);w(0x7c04,135);w(0xb6,135)
  w(0x69,1);w(0x68,0);w(0x7d06,1);w(0x7d07,1)
 end
 assert((r(0x6a)&8)~=(0)==(tick<cases[index].hold),'physical Up reaches the movement code')
 armed=true
end,emu.callbackType.exec,H.Step)
emu.addEventCallback(function()f=f+1;assert(f<2600,'bounded Kung Fu physics audit')end,emu.eventType.endFrame)
