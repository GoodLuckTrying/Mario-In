local f=0
local booted=false
local p=PLAYER or 0
local power=POWER or 0
local hits=0
local minY=255
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for q=0,1 do setPad(q,{start=q==0 and not booted and f%90<4,left=q==p and f>=650 and f<980,b=q==p and f>=650 and f<980,a=q==p and f>=720 and f%90<30}) end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=650 then hits=hits+1;print('DAMAGE '..f..' x '..r(0x500+p)..':'..r(0x4f0+p)..' y '..r(0x520+p)..':'..r(0x510+p)..' tile '..r(0x10)) end
end,emu.callbackType.exec,H.Damage)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==710 then
  if p==1 then
   w(0x50,1);w(0x4d1,0x80);w(0x401,0xd0);w(0x4f1,r(0x4f0));w(0x501,r(0x500));w(0x511,r(0x510));w(0x521,r(0x520));w(0x55,0)
   w(0x4d0,0)
   local base=0x6800+p*128
   for o=0,0x4f do w(base+o,0) end
   w(base,0x4d);w(base+0xb,1);w(base+0xc,1);w(base+0x14,1);w(base+0x15,8);w(base+0x1b,0x70)
  end
  w(0x6804+p*128,power);w(0x684c+p*128,2);w(0x69c4,0);w(0x69c5,0);w(0x5e+p,0)
  if FIXTURE then
   for s=2,15 do w(0x4d0+s,0) end
   for a=0x600,0x6ff do w(a,0) end
   for x=0,31 do w(0x600+96+x,0x44) end
   for x=0,31 do w(0x600+16+x,0x03) end
   w(0xfa,0);w(0xfb,5);w(0xfc,0);w(0xfd,0)
   w(0x4f0+p,16);w(0x500+p,0);w(0x510+p,20);w(0x520+p,5)
   w(0x6805+p*128,0);w(0x54+p,0)
  end
 end
 if f>=720 then minY=math.min(minY,r(0x510+p)) end
 if f==1000 then
  print('corner hits '..hits..' power '..r(0x6804+p*128)..' x '..r(0x500+p)..':'..r(0x4f0+p)..' minY '..minY)
  assert(hits==0 and r(0x54+p)<6 and r(0x6804+p*128)==power,'Jumping into the opening left boundary must not hurt Mario')
  if FIXTURE then assert(minY<4,'Head probes above the viewport must not alias hazardous bottom-row tiles') end
  print('PASS opening corner player '..p..' power '..power);emu.stop(0)
 end
end,emu.eventType.endFrame)
