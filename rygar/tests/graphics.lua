local overhead=ENTRY~=nil and not SIDE
local f=0;local moved=false;local sampled=nil;local checks=0;local dynamic=0;local writes=0;local bad=0;local views={}
local file=assert(io.open(TEST_ROOT..'/build/source-art/mario-frames.chr','rb'));local frames=file:read('*a');file:close()
file=assert(io.open(TEST_ROOT..'/build/directional-frames.bin','rb'));local art=file:read('*a');file:close()
file=assert(io.open(TEST_ROOT..'/src/art.inc','r'));local tables=file:read('*a');file:close()
local tiles={};for hex in tables:match('MarioTiles:(.-)FireTiles:'):gmatch('%$([%x]+)')do tiles[#tiles+1]=tonumber(hex,16)end
local selected={0,1,2,24,4,10}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function p(a)return emu.read(a,emu.memType.nesPpuDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=f%240
 local step=ENTRY~=20 or f%16<2
 setPad(0,{start=f==120 or(f<180 and f%60==5),right=step and f>=500 and t<35,left=step and f>=500 and t>=40 and t<75,up=step and overhead and f>=500 and t>=80 and t<115,down=step and f>=500 and t>=120 and t<155,a=not overhead and f>=500 and t>=160 and t<180,b=f>=500 and t>=200 and t<202})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if ENTRY and f>=280 and not moved then
  moved=true;w(0x1d,ENTRY);w(0x301,6);w(0x41,0)
 end
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
end,emu.callbackType.exec,0x9B9A)
emu.addMemoryCallback(function()for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end end,emu.callbackType.exec,0x9C20)
emu.addMemoryCallback(function()
 sampled=nil
 if f<180 or r(0x210)>=239 then return end
 sampled={pose=r(H.M_POSE),dynamic=r(0x7d74)~=0 and r(0x7d6e)~=0,shown=r(0x7d6c),buffer=r(0x7d6f)}
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 local s=emu.getState();local pc=s['cpu.pc']
 if not((pc>=H.Palette and pc<H.FireUpdate)or(pc>=H.StreamArt and pc<H.MarioTiles))then return end
 writes=writes+1
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled'])then bad=bad+1 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if sampled and emu.getState()['ppu.mask.spritesEnabled']then
  for cell=0,3 do
   local tile=emu.read(17+cell*4,emu.memType.nesSpriteRam)
   local expected=sampled.dynamic and(sampled.buffer+cell*2)or tiles[sampled.pose*4+cell+1]
   assert(tile==expected,'hardware OAM must use committed body frame')
   for b=0,31 do
    local byte
    if sampled.dynamic then byte=art:byte(sampled.shown*128+cell*32+b+1)
    else
     assert(selected[sampled.pose+1],'legal side-view pose')
     byte=frames:byte(selected[sampled.pose+1]*128+(cell//2*4+cell%2+b//16*2)*16+b%16+1)
    end
    assert(p(tile*16+b)==byte,'complete hardware CHR cell '..cell..' frame '..f..' dynamic '..tostring(sampled.dynamic))
   end
  end
  for shade,color in ipairs({0x30,0x27,0x16})do assert(p(0x3f10+shade)==color,'hardware Fire Mario shade '..shade)end
  checks=checks+1
  if sampled.dynamic then dynamic=dynamic+1;views[sampled.shown//4]=true end
 end
 if f==1100 then
  assert(checks>200,'displayed graphics oracle exercised')
  if overhead then assert(dynamic>200,'native overhead direction streaming exercised: '..dynamic);assert(views[0]and views[4],'front and back displayed')end
  assert(writes>100 and bad==0,'custom PPU writes finish in vblank: '..bad..' / '..writes)
  print('PASS '..(ENTRY and'native overhead entry '..ENTRY or'side-view')..', '..checks..' frames, '..dynamic..' streamed frames, hardware colors and vblank');emu.stop(0)
 end
end,emu.eventType.endFrame)
