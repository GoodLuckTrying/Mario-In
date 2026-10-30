-- Native startup graphics, followed by controlled legal vertical-scroll states.
local f=0;local modes={};local sampled=nil;local checks=0;local phase=0;local ticks=0;local startY=0;local late=0;local grounded=0
local file=assert(io.open(TEST_ROOT..'/build/source-art/mario-frames.chr','rb'));local art=file:read('*a');file:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function p(a)return emu.read(a,emu.memType.nesPpuDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=f>=120 and f<180 and f%60<2})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()w(0x43,7)end,emu.callbackType.exec,0xd19b)
emu.addMemoryCallback(function()
 sampled=nil
 local m=r(0x10)
 if(m==7 or m==8)and not SKIP_ART then
  local base=m==7 and 0 or 20
  if r(0x200+base)>=239 then return end
  assert(r(0x7d35)~=0,'Mario art must be ready before the first visible life/spawn DMA')
  sampled={mode=m,base=base,pal=r(0x7d4d)}
 end
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 if f<400 or phase>=5 then return end
 for i=0,5 do w(0x650+i*16,0)end
 if phase==3 then
  assert((r(0x62)&31)<25,'landing on lower ground must remain alive')
  ticks=ticks+1
  grounded=r(H.M_STATE)==0 and grounded+1 or 0
  assert(ticks<16,'lower ground catches and supports a falling Mario')
  if grounded>=3 then
   phase=4;ticks=0
   w(0xc4,0);w(0x5d,r(0x5d)|0x20)
   for a=0x40c,0x4cb do w(a,0)end
   w(0x64,181);w(0x62,8);w(H.M_STATE,2);w(H.M_VY,4);w(H.M_VY_FRAC,0)
  end
  return
 end
 if phase==4 then
  if(r(0x62)&31)>=25 then phase=5 else ticks=ticks+1;assert(ticks<8,'real pit still triggers native death')end
  return
 end
 if phase==0 or ticks==8 then
  if phase>0 then
   local expected=phase==1 and 16 or 240
   assert(((r(0x0d)-startY)&255)==expected,'two native camera pixels per update: '..((r(0x0d)-startY)&255))
  end
  phase=phase+1;ticks=0
  if phase==3 then
   w(0xc4,0)
   for a=0x40c,0x4cb do w(a,0)end
   local row=(11+r(0x93))%12
   for x=0,15 do w(0x40c+row*16+x,1)end
   w(0x64,171);w(0x62,8);w(H.M_STATE,2);w(H.M_VY,4);w(H.M_VY_FRAC,0)
   return
  end
  -- Start a native 16-pixel vertical strip, using cleared collision cache.
  -- This isolates viewport death from enemies and from campaign geometry.
  for a=0x40c,0x4cb do w(a,0)end
  w(0xc4,phase==1 and 0x50 or 0x40);w(0xc5,0)
  w(0x63,128);w(0x64,phase==1 and 171 or 73);w(0x62,8)
  w(H.M_STATE,2);w(H.M_VY,phase==1 and 4 or 252);w(H.M_VY_FRAC,0);w(H.M_Y_FRAC,0)
  startY=r(0x0d)
 end
 if r(0xc4)&128==0 then return end
 assert((r(0x62)&31)<25,'valid camera scroll must not become a fall death: phase '..phase..' tick '..ticks..' action '..r(0x62)..' y '..r(0x64)..' c4 '..r(0xc4)..' c5 '..r(0xc5))
 ticks=ticks+1
end,emu.callbackType.exec,0xf28d)
emu.addMemoryCallback(function(a,v)
 if phase<1 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled'])then late=late+1 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if sampled and not SKIP_ART and emu.getState()['ppu.mask.spritesEnabled']then
  assert(sampled.pal<4,'Fire palette ready for presentation')
  for cell=0,3 do
   local tile=emu.read(sampled.base+cell*4+1,emu.memType.nesSpriteRam)
   assert(tile==0x21+cell*2,'Mario replaces every life/spawn body cell')
   for b=0,31 do
    local src=24*128+(cell//2*4+cell%2+b//16*2)*16+b%16+1
    assert(p(0x1000+(tile&254)*16+b)==art:byte(src),'displayed life/spawn CHR is Mario')
   end
  end
  for shade,color in ipairs({0x30,0x27,0x16})do assert(p(0x3f10+sampled.pal*4+shade)==color,'life/spawn Fire palette')end
  modes[sampled.mode]=true;checks=checks+1
 end
 if phase==5 then
  assert(SKIP_ART or(modes[7]and modes[8]and checks>100),'both native presentation paths displayed')
  assert(late==0,'accelerated strip uploads stay in vblank: '..late)
  print('PASS life/entrance Mario ('..checks..' frames), up/down camera speed and viewport survival');emu.stop(0)
 end
 assert(f<1300,'bounded camera/presentation replay')
end,emu.eventType.endFrame)
