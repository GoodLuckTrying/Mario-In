-- Native Mesen integration fixtures. RAM seeding is intentional and logged;
-- controller-only play is captured separately by baseline.lua.
local f=0
local seeded={}
local root=(TEST_ROOT..'/build/')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function at(n)
 if f>=n and not seeded[n] then seeded[n]=f;return true end
 return false
end
local function player(power,x,y)
 w(0x6804,power);w(0x723,x);w(0x720,y);w(0x721,0x80)
 w(0x6805,0);w(0x6818,0);w(0x6819,0);w(0x682A,0);w(0x682B,0);w(0x682C,0);w(0x6835,0);w(0x728,0)
 w(0x6806,0);w(0x6807,0);w(0x6808,0);w(0xA6,15);w(0xAB,0);w(0xA5,0)
end
local function enemy(x,y)
 w(0x7C1,0x11);w(0x7C0,y);w(0x7C3,x);w(0x7C2,0);w(0x7C4,0);w(0x7C5,0);w(0x7C7,1);w(0x7C8,0)
end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,b=f==610 or f==615 or f==620,a=false},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if at(550) then player(0,48,170);enemy(48,170);w(0x7C1,0x12);w(0x7C2,0xD0) end
 if at(570) then player(1,48,170);enemy(48,170);w(0x7C1,0x12);w(0x7C2,0xD0) end
 if at(600) then player(2,48,170);w(0x739,0);w(0x73D,0) end
 if at(650) then player(2,48,170);w(0x6830,3);w(0x6831,48);w(0x6832,156);w(0x6833,120);w(0x68AC,0) end
 if at(670) then player(0,48,170);w(0x6830,4);w(0x6831,48);w(0x6832,156);w(0x6833,120);w(0x68AC,0) end
 if at(730) then player(2,144,170);enemy(144,170) end
 if at(780) then player(0,144,170);enemy(144,170);w(0x68AE,3) end
end,emu.callbackType.exec,0xCBB6)
emu.addEventCallback(function()
 f=f+1
 if f==552 then assert(r(0x6804)==1,'Native heart must grow Small Mario');assert(r(0x14A)>0,'Native heart currency must still be credited');print('Native mushroom-equivalent heart pickup passed') end
 if f==572 then assert(r(0x6804)==2,'Native heart must upgrade Super Mario to fire');print('Native flower-equivalent heart pickup passed') end
 if f==612 then
  assert(r(0x739)>=128 or r(0x73D)>=128,'B must create an active fireball')
  print('Fireball spawn passed')
 end
 if f==652 then assert(r(0x682B)+256*r(0x682C)>0,'Star pickup must start invincibility');print('Star pickup passed') end
 if f==672 then assert(r(0x68AE)==4,'1-up must add one life');print('1-up pickup passed') end
 if f==732 then
  assert(r(0x6804)==0,'Enemy contact must shrink Fire Mario')
  assert(r(0x682A)>0,'Shrinking must grant invincibility')
  print('Shrink damage passed')
 end
 if f==782 then assert(r(0x721)&0x40~=0,'Small Mario must die on enemy contact');print('Small damage passed') end
 if f==1000 then
  assert(r(0xA0)==2,'Death retry must return to native stage')
  assert(r(0x68AE)==2,'Death must consume exactly one of three lives')
  assert(r(0x721)&0x40==0,'Retry must restore active Mario')
  print('Life retry passed')
  local o=assert(io.open(root..'verified-abilities.png','wb'));o:write(emu.takeScreenshot());o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
