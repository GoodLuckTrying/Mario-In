local f=0;local sampled=nil;local checks=0;local poses={};local badWrites=0
local file=assert(io.open(TEST_ROOT..'/build/source-art/mario-frames.chr','rb'));local frames=file:read('*a');file:close()
local selected={0,1,2,24,4,3,10,8,9,11,22}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function p(a)return emu.read(a,emu.memType.nesPpuDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or(f<180 and f%60==5),right=f>=320 and f<355,left=f>=360 and f<390,a=f>=410 and f<435,down=f>=510 and f<540,b=f>=550 and f%40<2})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()w(0x43,STAGE or 0)end,emu.callbackType.exec,0xD19B)
emu.addMemoryCallback(function()
 if f>300 then for i=0,5 do w(0x650+i*16,0)end end
end,emu.callbackType.exec,0xF28D)
emu.addMemoryCallback(function()
 sampled=nil
 if r(0x7d35)==0 or r(0x10)<8 or r(0x10)>=16 then return end
 if r(0x214)>=239 then return end
 sampled={pose=r(H.M_POSE),pal=r(0x216)&3}
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 local pc=emu.getState()['cpu.pc']
 if pc<H.Palette or pc>=H.SpawnFire then return end
 local s=emu.getState();if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled'])then badWrites=badWrites+1 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if sampled and emu.getState()['ppu.mask.spritesEnabled']then
  local pose=sampled.pose;assert(selected[pose+1],'legal Mario pose')
  assert(emu.getState()['ppu.control.largeSprites'],'native 8x16 format preserved')
  local frame=selected[pose+1]*128
  for cell=0,3 do
   local tile=emu.read(21+cell*4,emu.memType.nesSpriteRam)
   assert(tile==0x21+cell*2,'complete Mario body cells')
   local row=cell//2;local col=cell%2
   for b=0,31 do
    local src=frame+(row*4+col+(b//16)*2)*16+b%16+1
    assert(p(0x1000+(tile&254)*16+b)==frames:byte(src),'hardware Mario CHR stage '..(STAGE or 0)..' pose '..pose..' cell '..cell)
   end
  end
  for shade,color in ipairs({0x30,0x27,0x16})do assert(p(0x3f10+sampled.pal*4+shade)==color,'hardware Fire Mario palette stage '..(STAGE or 0)..' actual '..p(0x3f10+sampled.pal*4+shade))end
  checks=checks+1;poses[pose]=true
 end
 if f==800 then
  assert(r(0x61)==(STAGE or 0),'native stage selection used')
  assert(checks>50,'hardware oracle exercised: '..checks)
  assert(badWrites==0,'custom palette writes must finish inside vblank: '..badWrites)
  print('PASS stage '..(STAGE or 0)..', '..checks..' displayed frames, complete body/colors and vblank timing');emu.stop(0)
 end
end,emu.eventType.endFrame)
