-- Controlled swings, then the original authored wall/destruction handlers.
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
 for _,a in ipairs({0x28,0x46,0x40,0x41,0x38c,0x2e,0x2f,0x49,0x600b,0x3f,0x354,0x46c,0x450,0x6001,0x6004,0x6005,0x6006}) do saved[a]=r(a) end
 for a=0x5a0,0x6ff do savedTiles[a]=r(a) end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 for a=0x5a0,0x6ff do w(a,0) end
 w(0x28,1);w(0x46,0);w(0x600b,1)
 w(0x2e,128);w(0x2f,3);w(0x49,0)
 local world=(scenario==2 and 984 or scenario==3 and 1044 or 970)
 local small=scenario==0 or scenario==2 or scenario==3 or scenario==7
 w(0x40,world%256);w(0x41,math.floor(world/256));w(0x38c,world-896)
 w(0x6001,small and 0 or 1);w(0x600d,90);w(0x46c,0);w(0x450,scenario==3 and 1 or 0)
 w(0x3f,small and 136 or 148);w(0x354,r(0x3f));w(0x603e,13);w(0x6039,0)
 w(0x146,0);w(0x147,0);w(0x148,0);w(0x72,0)
 w(0x6030,0);w(0x6031,0);w(0x6020,0);w(0x6021,0)
 before=r(0x6038)
 -- Stage 1's original brick, world X $3F0 / Y $90.
 for x=240,248,8 do for y=144,152,8 do tile(x,y,1) end end
 tile(224,144,1)
 if scenario==4 then w(0x3f,116);w(0x354,116)
 elseif scenario==5 then w(0x146,1)
 elseif scenario==6 then w(0x46,1)
 elseif scenario==7 then
  -- Stage 2's original hidden food wall in the lower room.
  w(0x28,2);w(0x600b,2);w(0x46,1);w(0x2e,0);w(0x2f,1)
  w(0x40,232);w(0x41,0);w(0x38c,80);w(0x3f,184);w(0x354,184)
  for a=0x5a0,0x6ff do w(a,0) end
  for x=0,8,8 do for y=192,200,8 do tile(x,y,1) end end
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if scenario==nil or (frame-700)%20~=0 then return end
 assert(r(0x603e)==12 and r(0x6039)==1,'Extended swing must queue one wall probe')
 assert(r(0x603d)==(r(0x6001)==0 and 12 or 20),'Wall reach must scale with Mario')
 -- Two live fireballs must survive the separate whip wall handler.
 w(0x6020,1);w(0x6021,1);w(0x602c,50);w(0x602d,50)
end,emu.callbackType.exec,0xe8f0)
emu.addMemoryCallback(function()
 if scenario==nil or (frame-701)%20~=0 then return end
 local n=scenario
 scenario=nil
 local shouldBreak=n==1 or n==2 or n==3 or n==7
 assert(r(0x6039)==0,'Whip wall probe must be consumed once')
 assert(r(0x6038)==before+(shouldBreak and 1 or 0),'Whip wall range case '..n)
 assert(r(0x6020)==1 and r(0x6021)==1,'Whip must not consume fireball slots')
 if shouldBreak then
  assert(r(0x146)==1,'Original wall persistence')
  local x=n==7 and 0 or 240
  local y=n==7 and 192 or 144
  for xx=x,x+8,8 do for yy=y,y+8,8 do assert(collision(xx,yy)==0,'All four brick collision quadrants must clear') end end
  if n~=7 then assert(collision(224,144)==1,'Neighbouring ordinary terrain must remain') end
  local drops,debris=0,0
  for actor=4,27 do
   if r(0x434+actor)==0x2f then
    drops=drops+1
    assert(r(0x584+actor)==(n==7 and 5 or 0x11),'Original hidden item must remain')
   end
   if actor>=24 and r(0x434+actor)==3 then debris=debris+1 end
  end
  assert(drops==1 and debris==4,'Native hidden item and debris must spawn')
 else
  assert(collision(240,144)==1 and r(0x146)==(n==5 and 1 or 0),'Miss/persistence/room must preserve wall')
 end
 completed=completed+1
 print('Native whip brick case '..n..' passed')
 for a,v in pairs(saved) do w(a,v) end
 for a,v in pairs(savedTiles) do w(a,v) end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 w(0x6020,0);w(0x6021,0);w(0x603e,0)
 if n==7 then assert(completed==8,'All eight whip brick cases must run');emu.stop(0) end
end,emu.callbackType.exec,0xcef0)
emu.addEventCallback(function() frame=frame+1;if frame==880 then print('FAIL missing whip wall fixture');emu.stop(1) end end,emu.eventType.endFrame)
