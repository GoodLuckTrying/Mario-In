-- Real title selection and native turn swaps. Contact/position fixtures
-- trigger deaths; player index, life counts and respawn flow stay native.
local f=0;local turn=0;local owner=0;local active=0;local killed=false
local seen={0,0};local shots={0,0};local swaps=0;local p2options=false
local original=assert(io.open('C:/nes/Gradius (USA).nes','rb')):read('*a')
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local function ppu(a)return emu.read(a,emu.memType.nesPpuDebug)end
emu.addEventCallback(function()
 for p=0,1 do
  local current=r(0x18)==p and turn>0
  setPad(p,{select=p==0 and f>=180 and f<183,start=p==0 and f>=200 and f<203,
   a=current and not killed,up=current and r(0x320)>90,
   b=current and owner==1 and(active==20 or active==60),
   right=current and active>=30 and active<40,left=not current and turn>0})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if turn==0 or r(0)~=5 or r(0x100)~=1 then return end
 local p=r(0x18);local attr=p==0 and 3 or 0
 for i=0,3 do assert(r(0x7106+i*4)==attr,'all four body cells use the active brother palette')end
 for i=0,15 do
  local wanted=original:byte(16+0x879a-0x8000+i+1)
  if p==1 and i==1 then wanted=0x1a end
  assert(ppu(0x3f10+i)==wanted,'only the approved shared green shade changes on Luigi turns')
 end
 seen[p+1]=seen[p+1]+1
 if p==1 and r(0x45)==2 and r(0x121)~=0 and r(0x122)~=0 then
  for i=4,11 do assert(r(0x7106+i*4)==0,'both acquired Options also use Luigi colors')end
  p2options=true
 end
end,emu.callbackType.exec,0x80aa)
emu.addMemoryCallback(function()
 if turn>0 then local p=r(0x18);if r(0x123)~=0 then shots[p+1]=shots[p+1]+1 end end
 if not killed and turn>0 and swaps<2 and active>=(owner==1 and 140 or 100)and r(0x100)==1 then
  killed=true;w(0x7005,0);w(0x46,0);w(0x360,80);w(0x320,96)
  for i=12,31 do w(0x120+i,0);w(0x100+i,0);w(0x300+i,0)end
  w(0x10c,1);w(0x12c,0x11);w(0x30c,0x85);w(0x36c,80);w(0x32c,96);w(0x460,0)
 end
end,emu.callbackType.exec,0x9a70)
emu.addMemoryCallback(function()
 if turn>0 and r(0x18)~=owner then
  swaps=swaps+1;owner=r(0x18);active=0;killed=false
 end
end,emu.callbackType.exec,0x97dd)
emu.addMemoryCallback(function()
 if f<450 or r(0)~=5 then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'character palette updates stay inside blanking')
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==450 then assert(r(3)==0x70 and(r(0x0a)&3)==3 and r(0x18)==0,'Select and Start enter the original two-controller alternating mode: '..r(3)..'/'..r(0x0a)..'/'..r(0x18));turn=1 end
 if turn>0 and r(0)==5 and r(0x100)==1 and r(0x1b)>=128 then
  active=active+1
  if not killed then w(0x7005,1)end
  if owner==1 and(active==10 or active==50)then w(0x42,5)end
  if active==90 then
   local file=assert(io.open(TEST_ROOT..'/build/brother-turn-'..swaps..'.png','wb'));file:write(emu.takeScreenshot());file:close()
  end
  if swaps==2 and active>=100 then
   assert(owner==0 and r(0x20)==2 and r(0x21)==2,'one real contact death per brother preserves native lives and returns to Mario')
   assert(seen[1]>100 and seen[2]>100 and shots[1]>20 and shots[2]>20 and p2options,'both brothers fly/fire and Luigi acquires two matching Options')
   print('PASS native two-player title choice, Mario -> Luigi -> Mario contact-death turns, palettes, fireballs and Luigi Options');emu.stop(0)
  end
 end
 assert(f<4000,'bounded alternating-player replay, swaps '..swaps..' owner '..owner..' active '..active)
end,emu.eventType.endFrame)
