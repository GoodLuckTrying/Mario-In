local f=0
local p=PLAYER or 0
local power=POWER or 0
local base=0x6800+p*128
local booted=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function tile(x,y,code)
 local a=0x600+math.floor(y/32)*16+math.floor(x/16);local old=r(a)
 w(a,y%32>=16 and ((old%16)+code*16) or (math.floor(old/16)*16+code))
end
emu.addEventCallback(function()setPad(0,{start=not booted and f%90<4});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then
  w(0x98,0);w(0x50,1);w(0xfc,0);w(0xfd,0);w(0xfa,0);w(0xfb,5)
  for q=0,15 do w(0x4d0+q,q==p and 0x80 or 0) end
  for q=0,1 do w(0x54+q,q==p and 2 or 12);w(0x56+q,0);w(0x5e+q,0) end
  for a=0x600,0x6ff do w(a,0) end
  for x=0,240,16 do tile(x,176,4);tile(x,192,3);tile(x,208,3) end
  for i=0,0x4f do w(base+i,0) end
  w(base,0x4d);w(base+4,power);w(base+5,2);w(base+0x18,2);w(base+11,1);w(base+12,1)
  w(base+0x14,1);w(base+0x15,8);w(base+0x1b,0x70);w(base+0x37,0)
  w(0x4f0+p,120);w(0x500+p,0);w(0x510+p,158);w(0x520+p,5);w(0x400+p,0xd0)
  w(0x68+p,120);w(0x6a+p,0)
 end
 if f==708 then
  if power==0 then assert(r(0x54+p)==10,'Descending onto electrical terrain must kill small form')
  else assert(r(base+4)==0 and r(0x5e+p)>0,'Electrical terrain must shrink tall forms') end
  assert(r(base+0x18)<128,'Electrical terrain must not provide a stomp bounce')
  print('PASS electric terrain landing player '..p..' form '..power);emu.stop(0)
 end
end,emu.eventType.endFrame)
