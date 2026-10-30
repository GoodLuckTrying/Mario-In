local f=0
local p=PLAYER or 0
local base=0x6800+p*128
local mode=MODE or 'hit'
local booted=false
local maximum=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for q=0,1 do
  setPad(q,{start=q==0 and not booted and f%90<4,b=(q==p or COOP) and f>=720 and f<750 and f%8<4})
 end
end,emu.eventType.inputPolled)
local seeded=false
emu.addMemoryCallback(function()
 if seeded or f<700 then return end
 seeded=true

  w(0x98,0);w(0x50,1)
  for q=0,1 do
   w(0x4d0+q,(q==p or COOP) and 0x80 or 0);w(0x400+q,0xD0);w(0x54+q,0);w(0x56+q,0);w(0x5e+q,120)
   w(0x4f0+q,90+(q==p and 20 or 0));w(0x500+q,0);w(0x510+q,180);w(0x520+q,5)
   local b=0x6800+q*128
   w(b,0x4D);w(b+4,2);w(b+5,0);w(b+6,0);w(b+0x35,0);w(b+0x4c,2);w(b+0xb,1);w(b+0xc,1);w(b+0x14,1);w(b+0x15,8)
   w(0x69c4+q,0)
  end
  for s=2,15 do w(0x4d0+s,0) end
  if mode=='hit' then
   local s=15
   for a=0x400+s,0x580+s,16 do w(a,0) end
   w(0x4d0+s,0xC1);w(0x400+s,0xD0);w(0x4e0+s,2);w(0x420+s,0x1C);w(0x490+s,120)
   w(0x4f0+s,150);w(0x500+s,0);w(0x510+s,180);w(0x520+s,5);w(0x570+s,0x40)
  end
end,emu.callbackType.exec,0xc77b)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end

 if f>720 and f<770 then
  local n=0;for s=0,3 do if r(0x69a0+s)>0 then n=n+1 end end
  maximum=math.max(maximum,n)
  assert(n<=(COOP and 4 or 2),'Independent two-fireball limit')
 end
 if f==780 then
  print('maximum '..maximum..' enemy '..r(0x4ef))
  assert(maximum>0,'B must spawn fireballs in Fire form')
  if mode=='hit' then assert(r(0x4ef)==0x1C or r(0x4df)==0,'Fireball must defeat native enemy')
  else assert(maximum==(COOP and 4 or 2),'Both available fireball slots must work') end
  assert(r(base+4)==2,'Shooting preserves Fire form')
  print('PASS fire '..mode..' player '..p..' coop '..tostring(COOP));emu.stop(0)
 end
end,emu.eventType.endFrame)
