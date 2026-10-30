-- Inspect the native pose dispatch, actual VRAM writes and displayed CHR.
-- DMA timing alone does not catch an invalid background-command pointer.
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function playing()return r(0x50)==1 and (r(0x51)==1 or r(0x51)==2 or r(0x51)==3)end
local file=assert(io.open('C:/nes/Kung Fu (Japan, USA) (En).nes','rb'))
local original=file:read('*a');file:close()
local modified={[6]=true,[7]=true,[8]=true,[9]=true,[12]=true,[13]=true,[15]=true,[0xd6]=true,[0xd7]=true,[0xd8]=true,[0xe6]=true,[0xe7]=true,[0xef]=true}
KUNGFU_GRAPHICS_CHECKS=0
local dma=0
emu.addMemoryCallback(function()
 assert(emu.getState()['cpu.x']~=6,'native Thomas sprite body must not overlap Mario')
end,emu.callbackType.exec,0xB2D5)
emu.addMemoryCallback(function()
 if playing() and r(0x4a6)<128 then
  local mode=r(0x69)&14
  assert(mode==0 or mode==2 or mode==4 or mode==6 or mode==8,'native animation dispatch must not combine hurt and airborne states')
 end
end,emu.callbackType.exec,0xA834)
emu.addMemoryCallback(function()
 if playing() then
  assert(r(0x52)<0x4f,'native background command index must remain inside its table: '..r(0x52))
  KUNGFU_GRAPHICS_CHECKS=KUNGFU_GRAPHICS_CHECKS+1
 end
end,emu.callbackType.exec,0x82EE)
emu.addMemoryCallback(function()
 if playing() then
  local s=emu.getState()
  assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'VRAM data writes must not overrun into the visible screen')
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function(_,value)
 if playing() and value&0x18~=0 then
  local s=emu.getState()
  assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'rendering must be restored within vblank: line '..s['ppu.scanline']..' dot '..s['ppu.cycle']..' command '..r(0x52))
  if r(0x52)==0 and r(0x218)<240 and r(0x4a6)<128 then
   local expected=r(0x7c00)==2 and {0x37,0x27,0x16} or {0x16,0x27,0x18}
   for i=1,3 do assert(emu.read(0x3f10+i,emu.memType.nesPpuDebug)==expected[i],'visible Mario must retain his palette after native transitions')end
  end
 end
end,emu.callbackType.write,0x2001)
emu.addMemoryCallback(function()
 if not playing() then return end
 dma=dma+1
 if dma%120~=0 then return end
 for tile=0,511 do
  local stair=r(0x7c3a)>=31 and r(0x7c3a)<=34
  local hud=stair and (tile==0x5b or tile==0xbc or tile==0xbd or tile==0xfd or tile==0xfe)
  if not modified[tile] then
   for n=0,15 do
    assert(emu.read(tile*16+n,emu.memType.nesPpuDebug)==original:byte((hud and 0x9010 or 0x8010)+tile*16+n+1),'displayed native CHR must be preserved, tile '..tile)
   end
  end
 end
 KUNGFU_GRAPHICS_CHECKS=KUNGFU_GRAPHICS_CHECKS+1
end,emu.callbackType.write,0x4014)

-- The original lower scroll restore is timed by its OAM copy/fill pass.
-- Mario reserves more cells, so check the actual split, not just VRAM bytes.
emu.addMemoryCallback(function(_,value)
 local q=emu.getState()
 if r(0x50)==1 and r(0x51)==3 and r(0x60)==3 and q['cpu.pc']==0x8E8D and q['ppu.scanline']>130 and q['ppu.scanline']<240 then
  assert(q['ppu.scanline']>=183,'lower stair scroll split must stay below the floor: '..q['ppu.scanline'])
 end
end,emu.callbackType.write,0x2005)
