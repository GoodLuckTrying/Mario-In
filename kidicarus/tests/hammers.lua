local f=0
local seeded={}
local power=POWER or 0
local facing=FACING or 1
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function enemy(x,y)
 w(0x7C1,0x11);w(0x7C0,y);w(0x7C3,x);w(0x7C2,0);w(0x7C4,0);w(0x7C5,0);w(0x7C7,1);w(0x7C8,0)
end
local function player()
 w(0x6804,power);w(0x723,128);w(0x720,184);w(0x721,0x80);w(0x680B,facing)
 w(0x6805,0);w(0x6818,0);w(0x6819,0);w(0x682A,0);w(0x682B,0);w(0x682C,0);w(0x6835,0)
 w(0x6806,0);w(0x6807,0);w(0x6808,0);w(0x728,0);w(0xA6,15)
end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,select=f==650 or f==710,b=f==670 or f==730},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=600 and not seeded[600] then
  seeded[600]=true;player();w(0xFD,0);w(0x14F,2);w(0x3E,100)
  for a=0x500,0x6DF do w(a,0) end
  for x=0,15 do w(0x5C0+x,0x50);w(0x6B0+x,0x50) end
  for a=0x761,0x7F1,8 do w(a,0) end
  enemy(128,184)
 end
 if f>=640 and not seeded[640] then
  seeded[640]=true;player();w(0x3E,0);w(0x7C1,0)
 end
 if f>=668 and not seeded[668] then
  seeded[668]=true;player();enemy(facing==1 and 144 or 112,184)
 end
end,emu.callbackType.exec,0xCBB6)
emu.addEventCallback(function()
 f=f+1
 if f==610 then
  print('pickup inventory='..r(0x14F)..' flags='..r(0x7C1)..' transformed='..r(0x3E)..' playerY='..r(0x720)..' enemyY='..r(0x7C0)..' playerX='..r(0x723)..' enemyX='..r(0x7C3))
  assert(r(0x14F)==3 and r(0x7C0)>=240,'Falling transformed mallet must enter inventory')
  assert(r(0x6804)==power and r(0x721)&0x40==0,'Collecting a mallet must not hurt Mario')
  print('Falling mallet pickup passed')
 end
 if f==660 then assert(r(0x3C)==1 and r(0x739)>=128,'Select equips a visible native hammer') end
 if f==690 then
  print('hammer power='..power..' facing='..facing..' inventory='..r(0x14F)..' enemy='..r(0x7C1))
  assert(r(0x14F)==2,'A successful hammer hit consumes one mallet')
  assert(r(0x7C1)~=0x11,'Hammer swing must damage the native enemy')
  assert(r(0x6804)==power and r(0x721)&0x40==0,'Using a hammer preserves Mario movement/form')
 end
 if f==720 then assert(r(0x3C)==0,'Select puts the hammer away') end
 if f>=750 then
  if power==2 then assert(r(0x739)>=128 or r(0x73D)>=128,'Putting away the hammer restores fireballs') end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
