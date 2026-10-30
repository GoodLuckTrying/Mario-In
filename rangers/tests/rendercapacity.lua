local f=0
local booted=false
local seeded=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()setPad(0,{start=not booted and f%90<4});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<720 or seeded then return end
 seeded=true
 for i=0,252,4 do w(0x200+i,100);w(0x201+i,1);w(0x202+i,1);w(0x203+i,i) end
 w(0x97,0)
 for p=0,1 do
  w(0x4d0+p,(p==0 or COOP) and 0x80 or 0);w(0x54+p,0);w(0x56+p,0);w(0x5e+p,0)
  w(0x4f0+p,80+p*40);w(0x500+p,0);w(0x510+p,180);w(0x520+p,5)
  w(0x6800+p*128,0x4d);w(0x6804+p*128,1)
 end
 for i=0,3 do
  w(0x69a0+i,(COOP or i<2) and 10 or 0)
  w(0x69a4+i,80+i*20);w(0x69a8+i,0);w(0x69ac+i,160);w(0x69b0+i,5);w(0x69c0+i,i%2)
 end
end,emu.callbackType.exec,H.Compose)
emu.addMemoryCallback(function()
 if seeded then
  assert(r(0x698a)==0,'Capacity fixture must fill all 64 hardware sprites exactly')
  assert(r(0x64fc)==160,'Full custom OAM must retain its last fireball instead of blanking all sprites')
  assert(r(0x6400)<240 and r(0x6982)==1,'A full sprite page must remain ready for DMA')
  print('PASS full sprite capacity coop '..tostring(COOP));emu.stop(0)
 end
end,emu.callbackType.exec,0xc83a)
emu.addEventCallback(function() f=f+1;if r(0x31)==0 and r(0x4d0)>=128 then booted=true end end,emu.eventType.endFrame)
