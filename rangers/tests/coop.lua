local f=0
local booted=false
local carrier=CARRIER or 0
local other=1-carrier
local held=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for p=0,1 do
  setPad(p,{start=p==0 and not booted and f%90<4,right=p==0 and not booted and f%30<4,
   b=p==carrier and ((f>=720 and f<728) or (f>=790 and f<798))})
 end
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==650 then assert(r(0x50)==1 and r(0x4d1)>=128,'Two-player selection must activate Luigi') end
 if f==700 then
  w(0x98,0)
  for s=2,15 do w(0x4d0+s,0) end
  for p=0,1 do
   w(0x54+p,0);w(0x56+p,0);w(0x400+p,0xD0);w(0x4f0+p,p==carrier and 160 or 174);w(0x500+p,0);w(0x510+p,180);w(0x520+p,5)
   w(0x6800+p*128,0x4D);w(0x6804+p*128,POWER or 0);w(0x6805+p*128,0);w(0x6806+p*128,0);w(0x684C+p*128,2);w(0x69c4+p,0)
  end
 end
 if f==735 then
  print('carrier '..r(0x56+carrier)..' other state '..r(0x54+other)..' pos '..r(0x4f0+carrier)..','..r(0x4f0+other)..' vel '..r(0x530+other))
  held=r(0x56+carrier)==0x80+other
  assert(held and r(0x54+other)==6,'Either player can pick up the other')
 end
 if f==805 then
  assert(r(0x56+carrier)==0,'B must throw the other player')
  assert(r(0x54+other)~=10,'Thrown player survives native toss')
  print('PASS native co-op pickup/throw carrier '..carrier);emu.stop(0)
 end
end,emu.eventType.endFrame)
