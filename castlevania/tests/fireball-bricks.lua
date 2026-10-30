-- Controlled terrain contacts against the original authored wall records.
-- Native wall destruction, collision edits, debris and drops run unchanged.
local frame=0
local scenario=nil
local before=0
local saved={}
local savedTiles={}
local completed=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function tile(x,y,value)
 for _,base in ipairs({0x5a0,0x650}) do
  local addr=base+(y-48-y%8)+math.floor(x/32)
  local shift=(3-math.floor(x/8)%4)*2
  local old=r(addr)
  w(addr,old-(math.floor(old/2^shift)%4)*2^shift+value*2^shift)
 end
end
local function collision(x,y)
 local addr=0x650+(y-48-y%8)+math.floor(x/32)
 local shift=(3-math.floor(x/8)%4)*2
 return math.floor(r(addr)/2^shift)%4
end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 or frame>840 or (frame-700)%20~=0 then return end
 scenario=math.floor((frame-700)/20)
 for _,a in ipairs({0x28,0x46,0x40,0x41,0x2e,0x2f,0x49,0x600b,0x3f,0x354,0x46c,0x6004,0x6005,0x6006}) do saved[a]=r(a) end
 for a=0x5a0,0x6ff do savedTiles[a]=r(a) end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 for a=0x5a0,0x6ff do w(a,0) end
 w(0x28,1);w(0x46,0);w(0x600b,1)
 w(0x2e,128);w(0x2f,3);w(0x49,0)
 w(0x40,0x80);w(0x41,3);w(0x6001,2);w(0x600d,90)
 w(0x146,0);w(0x147,0);w(0x148,0);w(0x72,0)
 w(0x6030,0);w(0x6031,0)
 before=r(0x6038)
 -- Stage 1's actual hidden-item brick: world X $3F0, Y $90.
 for x=240,248,8 do for y=144,152,8 do tile(x,y,1) end end
 tile(224,144,1)             -- neighbouring ordinary terrain must survive
 w(0x6020,1);w(0x6021,0);w(0x602c,50)
 w(0x6022,108);w(0x6024,144);w(0x6026,0);w(0x6050,0);w(0x6028,0);w(0x602a,0)
 if scenario==1 then
  w(0x6022,124);w(0x602a,1) -- leftward impact
 elseif scenario==2 then
  w(0x6022,116);w(0x6024,137);w(0x6026,2) -- landing on brick
 elseif scenario==3 then
  w(0x6022,92)             -- only the ordinary neighbouring solid
 elseif scenario==4 then
  w(0x146,1)              -- native persistence already marks this wall broken
 elseif scenario==5 then
  w(0x46,1)               -- wall belongs to a different vertical room
 elseif scenario==6 then
  w(0x6021,1);w(0x602d,50);w(0x6023,108);w(0x6025,144);w(0x6027,0);w(0x6051,0);w(0x6029,0);w(0x602b,0)
 elseif scenario==7 then
  -- A different original record: Stage 2, lower room, hidden meat.
  w(0x28,2);w(0x600b,2);w(0x46,1);w(0x2e,0);w(0x2f,1)
  for a=0x5a0,0x6ff do w(a,0) end
  for x=0,8,8 do for y=192,200,8 do tile(x,y,1) end end
  w(0x6022,4);w(0x6024,192)
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if scenario==nil or (frame-701)%20~=0 then return end
 local n=scenario
 scenario=nil
 local shouldBreak=n~=3 and n~=4 and n~=5
 assert(r(0x6030)==0 and r(0x6031)==0,'Terrain contacts must be consumed once')
 assert(r(0x6038)==before+(shouldBreak and 1 or 0),'Authored wall hit count case '..n)
 if shouldBreak then
  assert(r(0x146)==1 and r(0x6020)==0,'Native wall persistence and projectile consumption')
  local x=n==7 and 0 or 240
  local y=n==7 and 192 or 144
  for xx=x,x+8,8 do for yy=y,y+8,8 do assert(collision(xx,yy)==0,'All four brick collision quadrants must clear') end end
  if n~=7 then assert(collision(224,144)==1,'Ordinary neighbouring solid must remain') end
  local drops,debris=0,0
  for actor=4,27 do
   if r(0x434+actor)==0x2f then
    drops=drops+1
    assert(r(0x584+actor)==(n==7 and 5 or 0x11),'Original hidden-item type must be preserved')
   end
   if actor>=24 and r(0x434+actor)==3 then debris=debris+1 end
  end
  assert(drops==1 and debris==4,'One native hidden drop and four debris actors')
 else
  assert(collision(240,144)==1 and r(0x146)==(n==4 and 1 or 0),'Nonmatching wall must remain unchanged')
  for actor=4,19 do assert(r(0x434+actor)~=0x2f,'Miss must not release hidden items') end
 end
 print('Native fireball brick case '..n..' passed')
 completed=completed+1
 for a,v in pairs(saved) do w(a,v) end
 for a,v in pairs(savedTiles) do w(a,v) end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 w(0x6020,0);w(0x6021,0)
 if n==7 then assert(completed==8,'All eight brick cases must execute');emu.stop(0) end
end,emu.callbackType.exec,0xcef0)
emu.addEventCallback(function() frame=frame+1;if frame==880 then print('FAIL missing brick fixture');emu.stop(1) end end,emu.eventType.endFrame)
