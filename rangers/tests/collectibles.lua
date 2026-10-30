local f=0
local booted=false
local p=PLAYER or 0
local base=0x6800+p*128
local nativeCount=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function tile(x,y,code)
 local a=0x600+((x>>8)&1)*128+((y&0xe0)>>1)+((x>>4)&15)
 local old=r(a)
 w(a,(y&16)==0 and ((old&0xf0)|code) or ((old&15)|(code<<4)))
end
local function pickup(code)
 w(0x4f0+p,120);w(0x500+p,0);w(0x510+p,164);w(0x520+p,5)
 w(base+5,0);w(base+0x18,0);w(base+0x19,0);w(base+0x17,0);w(0x54+p,0)
 tile(120,176,code)
end
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f>=600 and f<700 then
  assert(r(0x6804)==0 and r(0x69c4)==0 and r(0x69c5)==0,'Standing at the start must not grant or spawn free powerups')
 end
 if f==700 then
  for s=0,15 do w(0x4d0+s,0) end
  w(0x50,1);w(0x4d0+p,0x80);w(0x400+p,0xd0);w(0x56+p,0);w(0x5e+p,0)
  for o=0,0x4f do w(base+o,0) end
  w(base,0x4d);w(base+0xb,1);w(base+0xc,1);w(base+0x14,1);w(base+0x15,8);w(base+0x1b,0x70)
  for a=0x600,0x6ff do w(a,0) end
  for x=0,511,16 do tile(x,192,3);tile(x,208,3) end
  nativeCount=r(0x5ae+p*48)
  pickup(1)
 end
 if f==710 then
  assert(r(base+4)==1,'First native flower gives mushroom growth')
  assert(r(0x5ae+p*48)~=nativeCount,'Native collectible count must still increase')
 end
 if f==760 or f==820 then pickup(1) end
 if f==770 or f==830 then assert(r(base+4)==2,'Next flower gives Fire form; further flowers retain Fire form') end
 if f==900 then w(0x5e+p,0);pickup(4) end
 if f==910 then
  assert(r(base+4)==0,'Real hazard tiles must still shrink Mario')
  assert(r(0x6804+(1-p)*128)==0,'Collectibles upgrade only the collecting player')
  print('PASS native collectibles and hazards player '..p);emu.stop(0)
 end
end,emu.eventType.endFrame)
