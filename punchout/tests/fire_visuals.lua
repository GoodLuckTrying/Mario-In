local f=0;local spawns=0;local checks=0;local rises=0;local falls=0;local last={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f<1600 and f%180<3,b=f>=1700 and f%40<2,up=f>=1700 and f%320<160});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x6025)==spawns then return end
 spawns=r(0x6025)
 local slot=r(0x6010)==2 and 0 or 1
 local pose=r(0x61);if pose>=98 then pose=0 end
 assert(r(0x6014+slot)==r(H.LaunchY+pose),'fireball starts at the throwing hand height')
 assert(((r(0x6012+slot)+r(0x15))&255)==r(H.LaunchX+pose),'fireball starts centered on the throwing arm')
end,emu.callbackType.exec,0xa6bd)
emu.addMemoryCallback(function()
 local slot=0;local age=r(0x6010);local hi=r(0x601a)
 if age<2 or hi==0 then last={};return end
 local addr=r(0x6018)+256*hi
 local y=((addr&1023)>>5)*8
 if last.age and age>last.age and age-last.age<3 then
  if y<last.y then rises=rises+1 elseif y>last.y then falls=falls+1 end
 end
 last={age=age,y=y}
 local phase=((age>>2)&3)*4
 for k,delta in ipairs({0,32,1,33})do
  assert(emu.read(addr+delta,emu.memType.nesPpuDebug)==r(H.FireTiles+phase+k-1),'all four tiles of the visible 16px fireball are drawn')
  checks=checks+1
 end
end,emu.callbackType.exec,0xa5ec)
emu.addEventCallback(function()
 f=f+1
 if f==2800 then local o=assert(io.open(TEST_ROOT..'/build/fireballs-visible.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if f==4500 then
  assert(spawns>10 and checks>1000,'visible shots are exercised')
  assert(rises>0 and falls>0,'fireballs visibly rise and fall while advancing')
  print('PASS fireball visuals: '..spawns..' hand-centered launches, '..checks..' hardware tile checks, '..rises..' rising / '..falls..' falling samples');emu.stop(0)
 end
end,emu.eventType.endFrame)
