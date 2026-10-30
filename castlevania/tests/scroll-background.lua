-- Native room initialization and real controller movement over directed flat
-- collision support. Original PPU data and candle records remain untouched.
local frame=0;local case=0;local phase='startup';local timer=0;local expected={};local checked=0;local spawned=0;local candleChecks=0;local spawners={};local spawnerChecks=0
local cases={{stage=3,room=0,maximum=512,boss=true},{stage=4,room=1,maximum=256},{stage=5,room=0,maximum=512}}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function camera() return r(0x2e)+256*r(0x2f) end
local function prg(a) return emu.read(a<0xc000 and 0x10000+a-0x8000 or 0x1c000+a-0xc000,emu.memType.nesPrgRom) end
local function word(a) return prg(a)+256*prg(a+1) end
local function launch()
 case=case+1
 if not cases[case] then assert(candleChecks>100 and spawnerChecks>5,'Room routes must exercise visible native objects');print('Original backgrounds: '..checked..' tile/attribute checks; '..spawned..' candle spawns, '..candleChecks..' visible candle checks and '..spawnerChecks..' enemy-spawner placement checks in both directions');emu.stop(0);return end
 local c=cases[case];expected={};spawners={};phase='loading';timer=0
 w(0x28,c.stage);w(0x600b,c.stage);w(0x46,c.room);w(0x48,0);w(0xe2,0);w(0x2d,0);w(0x2e,0);w(0x2f,0);w(0x3b,0);w(0x18,5);w(0x19,0)
end
local function verifyBackground()
 local c=cases[case];local cam=camera()
 assert(cam%32==0,'Room boundary must be on a complete tile column')
 assert(r(0xfd)==cam%256,'PPU scroll must match the camera at a lock')
 local parity=prg(0xfbd6+c.stage)%2
 assert(r(0xff)%2==(math.floor(cam/256)%2+parity)%2,'PPU nametable must match the camera page')
 local data=word(word(0xfb23+c.stage*2)+c.room*2);local meta=word(0xf9fa+c.stage*2)
 for col=0,7 do for row=0,5 do
  local tile=prg(data+(math.floor(cam/32)+4+col)*6+row)
  assert(tile~=255,'Visible room column must have authored background data')
  for y=0,3 do for x=0,3 do
   if row>0 or y>=2 then
    local world=cam+col*32+x*8
    local page=(math.floor(world/256)%2+parity)%2
    local a=0x2000+page*0x400+(4+row*4+y)*32+math.floor(world%256/8)
    local want=prg(meta+tile*17+1+y*4+x)
    assert(emu.read(a,emu.memType.nesPpuMemory)==want,'Original background tile: stage '..c.stage..' room '..c.room..' camera '..cam..' PPU '..a)
    checked=checked+1
   end
  end end
  local world=cam+col*32
  local page=(math.floor(world/256)%2+parity)%2
  local a=0x23c0+page*0x400+(1+row)*8+math.floor(world%256/32)
  local want=prg(meta+tile*17)
  if row==0 then want=want-want%16+15 end
  assert(emu.read(a,emu.memType.nesPpuMemory)==want,'Original background palette attribute')
  checked=checked+1
 end end
 print('Verified '..checked..' original background tiles through stage '..c.stage..' room '..c.room..' camera '..cam)
end
emu.addEventCallback(function()
 emu.setInput({start=frame==120,right=phase=='right',left=phase=='left',b=phase=='right' or phase=='left'},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if phase=='startup' or phase=='loading' then return end
 w(0x600d,90);w(0x45,64);w(0x6001,1);w(0x3f,176);w(0x354,176);w(0x46c,0);w(0x6004,0);w(0x6005,0);w(0xf5,0);w(0x603e,0)
 for a=0x5a0,0x6ff do w(a,0) end
 for _,base in ipairs({0x5a0,0x650}) do for x=0,7 do w(base+144+x,0x55) end end
 for x=3,27 do if x<14 or x>19 then w(0x434+x,0);w(0x60a0+x,0) end end
end,emu.callbackType.exec,0x934c)
emu.addMemoryCallback(function()
 if case==0 then return end
 local cpu=emu.getState();local x=cpu['cpu.x'];local pointer=r(0xa)+256*r(0xb);local y=cpu['cpu.y']
 expected[x]={world=r(0x6d)*64-64+r(pointer+y),y=r(pointer+y+1),id=r(0x6d)};spawned=spawned+1
end,emu.callbackType.exec,0xd26c)
emu.addMemoryCallback(function()
 if case==0 or phase=='loading' then return end
 local cpu=emu.getState();local x=cpu['cpu.x']
 spawners[x]={world=r(0x6d)*64-64+cpu['cpu.a']}
end,emu.callbackType.exec,0xd1f0)
emu.addMemoryCallback(function()
 local delta=r(0x49);if delta>=128 then delta=delta-256 end
 for x,e in pairs(spawners) do
  local localX=r(0x172+x)+256*(r(0x160+x)%2)
  if r(0x3c)==2 and localX>=256 then localX=localX-512 end
  assert(camera()+localX+delta==e.world,'New enemy spawner must match its authored world position before native AI')
  spawnerChecks=spawnerChecks+1
 end
 spawners={}
end,emu.callbackType.exec,0xcf05)
emu.addEventCallback(function()
 frame=frame+1
 if frame>=700 and frame%300==0 then print('CASE '..case..' phase '..phase..' mode '..r(0x18)..' aux '..r(0x19)..' room '..r(0x46)..' stage '..r(0x28)..' cam '..camera()..' X '..r(0x38c)..' Y '..r(0x3f)) end
 if frame==700 then launch() end
 if phase=='loading' and r(0x18)==5 and r(0x19)==6 then phase='right';timer=0;w(0x38c,48);w(0x3a8,0);w(0x40,48);w(0x41,0);w(0x6071,0);w(0x6072,0);w(0x6073,0);w(0x6002,0);w(0x6003,0);w(0x3c,5) end
 if phase=='right' or phase=='left' or phase=='settleRight' or phase=='settleLeft' then
  assert(r(0xfd)==r(0x2e),'Background scroll shadow must track every actual camera step')
  for x=14,19 do
   local e=expected[x]
   if e and r(0x434+x)==0x28 and r(0x300+x)==0 and r(0x4dc+x)==e.id then
    assert(camera()+r(0x38c+x)==e.world,'Candle must retain authored world X: stage '..r(0x28)..' slot '..x..' actual '..(camera()+r(0x38c+x))..' expected '..e.world)
    assert(r(0x354+x)==e.y,'Candle must retain authored Y');candleChecks=candleChecks+1
   end
  end
 end
 if phase=='right' and camera()==cases[case].maximum then phase='settleRight';timer=0 end
 if phase=='left' and camera()==0 then phase='settleLeft';timer=0 end
 if phase=='settleRight' or phase=='settleLeft' then
  timer=timer+1
  if timer==80 then
   verifyBackground()
   if cases[case].boss then assert(r(0x48)~=0,'First-boss activation must retain its camera lock');launch()
   elseif phase=='settleRight' then phase='left';timer=0
   else launch() end
  end
 end
 assert(frame<4500,'Background route timeout')
end,emu.eventType.endFrame)
