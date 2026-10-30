local f=0
local p=PLAYER or 0
local power=POWER or 0
local mode=MODE or 'drop'
local base=0x6800+p*128
local booted=false
local minimum=255
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function tile(x,y,code)
 local i=((x>>8)&1)*128+((y&0xe0)>>1)+((x>>4)&15)
 local a=0x600+i;local old=r(a)
 if (y&16)==0 then w(a,(old&0xf0)|code) else w(a,(old&15)|(code<<4)) end
end
emu.addEventCallback(function()
 for q=0,1 do
  local active=q==p
  setPad(q,{start=q==0 and not booted and f%90<4,down=active and mode=='drop' and f>=720 and f<740,
   a=active and (mode=='drop' or mode=='ceiling') and f>=720 and f<745,
   right=active and mode=='wall' and f>=720 and f<770,b=active and mode=='wall' and f>=720 and f<770})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>720 and f<780 then minimum=math.min(minimum,r(0x510+p)) end
end,emu.callbackType.exec,H.DrawGate)
-- Seed before the native actor loop, never midway through a player update.
local seeded=false
emu.addMemoryCallback(function()
 if seeded or f<700 then return end
 seeded=true

  w(0x98,0);w(0x50,1)
  for s=0,15 do w(0x4d0+s,0) end
  w(0x4d0+p,0x80);w(0x400+p,0xD0);w(0x54+p,0);w(0x56+p,0);w(0x5e+p,120)
  for o=0,0x4f do w(base+o,0) end
  w(base,0x4D);w(base+4,power);w(base+0xb,1);w(base+0xc,1);w(base+0x14,1);w(base+0x15,8);w(base+0x1b,0x70);w(base+0x4c,2)
  w(0x4f0+p,120);w(0x500+p,0);w(0x520+p,5);w(0x69c4,0);w(0x69c5,0)
  for a=0x600,0x6ff do w(a,0) end
  for x=0,511,16 do tile(x,192,3);tile(x,208,3) end
  if mode=='drop' or mode=='landing' then
   for x=0,511,16 do tile(x,128,2) end
   w(0x510+p,mode=='drop' and 116 or 70)
   if mode=='landing' then w(base+5,2);w(base+0x18,4) end
  elseif mode=='wall' then
   for y=96,192,16 do tile(144,y,3) end
   w(0x510+p,180)
  elseif mode=='ceiling' then
   for x=0,511,16 do tile(x,128,3);tile(x,176,3) end
   w(0x510+p,164)
  elseif mode=='object' then
   w(0x510+p,100);w(base+5,2);w(base+0x18,4)
   local s=15
   w(0x4d0+s,0x80);w(0x400+s,0x90);w(0x4e0+s,0x10);w(0x420+s,0x26);w(0x570+s,0x81)
   w(0x4f0+s,120);w(0x500+s,0);w(0x510+s,180);w(0x520+s,5)
  end
end,emu.callbackType.exec,0xc77b)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end

 if f==800 then
  local y=r(0x510+p);local x=r(0x4f0+p)
  print(mode..' x '..x..' y '..y..' min '..minimum..' objectY '..r(0x51f)..' cameraY '..r(0xFA)..' state '..r(base+5))
  if mode=='drop' then assert(y==180,'Down+A must pass through upper platform and land below')
  elseif mode=='landing' then assert(y==116,'Fast landing must align feet to platform top')
  elseif mode=='wall' then assert(x==136,'Full-speed body must stop outside the wall')
  elseif mode=='ceiling' then assert(y==164 and minimum>=(power==0 and 148 or 164),'Head bump must leave body outside ceiling')
  elseif mode=='object' then assert(y==156,'Mario must stand on native movable object') end
  print('PASS terrain '..mode..' player '..p..' form '..power);emu.stop(0)
 end
end,emu.eventType.endFrame)
