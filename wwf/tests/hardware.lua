dofile(TEST_ROOT..'/tests/common.lua')
local src=assert(io.open(TEST_ROOT..'/build/tiles.chr','rb'));local tiles=src:read('*a');src:close()
src=assert(io.open(TEST_ROOT..'/build/tile-slots.bin','rb'));local slots=src:read('*a');src:close()
local frames=0;local last=nil;local gap=0;local checks=0
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if r(0xc)==4 and (first or mode()==0xA038)then
  local s=emu.getState()
  assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'Mario CHR writes occur only in native forced blank/vblank')
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function(a)
 if first then
  local pc=emu.getState()['cpu.pc']
  local bridge=(a==0x4f8 and pc==H.ControlBridge+3)or(a==0x4f9 and pc==H.ControlBridge+6)
   or(a==0x4e8 and(pc==H.PortraitBridge+3 or pc==H.NameBridge+3))
  assert(r(0xc)==4 or bridge,'native code must not use Mario private RAM at '..string.format('%04X',pc))
 end
end,emu.callbackType.write,0x4b0,0x4ff)
-- This fixture measures sustained graphics/attack stress, with live AI and
-- native poses. Restore energy before each update so a random early defeat
-- cannot change it into a menu test. Real damage and pins have separate replays.
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end
 if first then w(0x79,200);w(0x7a,200)end
end,emu.callbackType.exec,H.UpdateBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if first then if last then gap=math.max(gap,f-last)end;last=f;frames=frames+1 end
end,emu.callbackType.exec,0xABFF)
function input(t)return{a=t%31==2,b=t%17==3,left=t%240<100,right=t%240>=120 and t%240<220,up=t%360<70,down=t%360>=180 and t%360<250}end
function input2(t)return{b=t%19==2,a=t%43==3,right=t%220<90,left=t%220>=110 and t%220<200}end
function tick(t)
 if t<0 then return end
 if t%50==0 then
  for i=1,#slots do
   for j=0,15 do assert(emu.read(0x1000+slots:byte(i)*16+j,emu.memType.nesPpuDebug)==tiles:byte((i-1)*16+j+1),'immutable Mario/attack/fireball pattern data')end
  end
  checks=checks+1
 end
 if t==1200 then assert(gap<=1 and frames>1150,'no skipped active frames under simultaneous melee/fireballs');assert(checks>20,'repeated graphics audits');finish('CHR preservation, safe PPU timing, private RAM isolation, native split and simultaneous two-player attack stress')end
end
