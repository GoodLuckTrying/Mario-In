dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local mode=MODE or 'stack'
local startX=112+(OFFSET or 0)
local removed={}
local jumped=false
emu.addMemoryCallback(function()
 if first and f-first>=20 and not seeded then
  seeded=f
  for i=0,199 do w(0x400+i,0xef)end
  for a=0x7803,0x780b do w(a,0)end
  for a=0x7820,0x7825 do w(a,0)end
  w(0x7801,startX);w(0x7802,208)
  w(N.currentPiece,18);w(N.tetriminoX,5)
  w(N.tetriminoY,mode=='just-locked' and 17 or 1)
  w(N.playState,mode=='just-locked' and 2 or 1)
  w(N.fallTimer,0);w(N.autorepeatY,0)
  w(N.vramRow,0x20);w(N.player1_vramRow,0x20)
  if mode=='just-locked' then
   startX=128;w(0x7801,startX)
  else
   for x=0,9 do w(0x400+17*10+x,0x7b)end
   w(0x400+16*10+2,0x7c)
   w(N.vramRow,0);w(N.player1_vramRow,0)
  end
  for x=startX+2,startX+13 do removed[(x-96)//8]=true end
 end
 if seeded and mode=='busy' and f-seeded==19 then w(N.vramRow,0);w(N.player1_vramRow,0)end
end,emu.callbackType.exec,H.UpdateGate)
function input(age)
 local t=seeded and f-seeded or -1
 return{a=t>=20 and t<36}
end
emu.addMemoryCallback(function()
 if seeded then
  local s=emu.getState()
  assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'head-break redraws must use native vblank transfers')
 end
end,emu.callbackType.write,0x2007)
function tick(age)
 if not seeded then return end
 local t=f-seeded
 assert(r(0x780c)==0,'jumping into settled cells must never kill Mario')
 assert(r(0x7801)==startX and r(0x7802)>=208 and r(0x7802)<=208,'a head hit stops upward movement at the ceiling')
 if t>=22 and r(0x7820)~=0 then jumped=true end
 if t==100 then
  for x=0,9 do
   local existed=mode~='just-locked' or x>=3 and x<=6
   local expected=existed and not removed[x] and 0x7b or 0xef
   assert(r(0x400+170+x)==expected,'only the settled cells touched by the head may break: column '..x)
   local addr=0x2000+(6+17)*32+12+x
   assert(emu.read(addr,emu.memType.nesPpuDebug)==expected,'broken cells must disappear from the hardware nametable: column '..x)
  end
  if mode~='just-locked' then assert(r(0x400+162)==0x7c,'head breaks must not erase the next layer above')end
  assert(r(0x7811)==0 and r(N.player1_lines)==0 and r(N.player1_score)==0,'head breaking must not count as a stomp or award line-clear points')
  screenshot('head-break-'..mode..'-'..(OFFSET or 0))
  finish('controller head break under '..mode..' cells, alignment '..(OFFSET or 0)..', safe bonk, exact cell removal and native redraw')
 end
end
