-- Reproduce the loss of the crouching body during a live crouch jump.
local f=0;local p=PLAYER or 0;local power=POWER or 1;local b=0x6800+p*128
local grounded=false;local airborne=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function tile(x,y,code)
 local i=((x>>8)&1)*128+((y&0xe0)>>1)+((x>>4)&15);local a=0x600+i;local old=r(a)
 w(a,(y&16)==0 and((old&0xf0)|code)or((old&15)|(code<<4)))
end
emu.addEventCallback(function()
 for q=0,1 do setPad(q,{start=q==0 and f<680 and f%90<4,down=q==p and f>=720 and f<750,a=q==p and f>=725 and f<750})end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<700 then return end
 for i=2,15 do w(0x4d0+i,0)end
 w(0x5e+p,250)
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f==700 then
  w(0x98,0);w(0x50,1)
  for i=0,15 do w(0x4d0+i,0)end
  w(0x4d0+p,0x80);w(0x400+p,0xd0);w(0x54+p,0);w(0x56+p,0);w(0x5e+p,250)
  for i=0,0x4f do w(b+i,0)end
  w(b,0x4d);w(b+4,power);w(b+11,1);w(b+12,1);w(b+20,1);w(b+21,8);w(b+27,0x70);w(b+76,2)
  w(0x4f0+p,120);w(0x500+p,0);w(0x510+p,164);w(0x520+p,5)
  for a=0x600,0x6ff do w(a,0)end
  for x=0,511,16 do tile(x,176,3);tile(x,192,3)end
 end
 if f==724 then grounded=r(b+29)~=0 and r(b+5)==0 end
 if f>=728 and f<740 and r(b+5)==1 then
  airborne=airborne or r(b+29)~=0 and r(b+30)==0
 end
 if f==800 then
  assert(grounded and airborne,'physical crouch jump retains the short SMB1 body in the air')
  print('PASS Rescue Rangers P'..p..' power'..power..' retains crouching through flight')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
