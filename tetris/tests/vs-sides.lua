HUMAN=true
dofile(TEST_ROOT..'/tests/vs-common.lua')
local mode=MODE or 'walk'
local seeded=nil
local touched=false
local last=nil
local maxGap=0
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return {right=mode=='walk' and dt<46,left=mode=='walk-left' and dt<46}
end
function input2(t)
 if not seeded then return{}end
 local dt=f-seeded
 return {right=(mode=='push' or mode=='pin')and dt==5,left=mode=='push-left' and dt==5,a=mode=='rotate' and dt==5}
end
emu.addMemoryCallback(function()
 if not first then return end
 if last then maxGap=math.max(maxGap,f-last)end
 last=f
 if f-first<20 or seeded then return end
 seeded=f
 for i=0,199 do w(0x400+i,0xef)end
 for a=0x7803,0x780b do w(a,0)end
 for a=0x7820,0x7825 do w(a,0)end
 w(N.playState,1);w(N.vramRow,0x20);w(N.player1_vramRow,0x20);w(N.fallTimer,0);w(N.autorepeatY,0);w(0x78a4,0);w(0x78a8,0)
 w(N.currentPiece,(mode=='walk' or mode=='walk-left' or mode=='rotate')and 17 or 10)
 w(N.tetriminoX,mode=='pin' and 7 or 5);w(N.tetriminoY,18)
 w(0x7801,mode=='walk' and 100 or mode=='walk-left' and 160 or mode=='push-left' and 114 or mode=='pin' and 158 or mode=='rotate' and 144 or 142)
 w(0x7802,208)
end,emu.callbackType.exec,H.UpdateGate)
emu.addMemoryCallback(function()
 if not seeded then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'side collisions must not delay visible VRAM writes')
end,emu.callbackType.write,0x2007)
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 assert(r(0x780c)==0,'sides push or stop Mario without inflicting a falling head hit')
 assert(r(0x7801)>=96 and r(0x7801)<=160,'a push cannot leave the well')
 if mode=='walk' and r(0x7801)==122 then touched=true end
 if mode=='walk-left' and r(0x7801)==142 then touched=true end
 if dt==45 then
  assert(maxGap<=1 and last>=f-1,'live side collisions stay within one update per frame')
  if mode=='walk' then assert(touched and r(0x7801)==122,'rightward walking stops at the falling column')
  elseif mode=='walk-left' then assert(touched and r(0x7801)==142,'leftward walking stops at the falling column')
  elseif mode=='push' then assert(r(0x7801)==150 and r(N.player1_tetriminoX)==6,'a P2 piece move pushes Mario right')
  elseif mode=='push-left' then assert(r(0x7801)==106 and r(N.player1_tetriminoX)==4,'a P2 piece move pushes Mario left')
  elseif mode=='pin' then assert(r(0x7801)==158 and r(N.player1_tetriminoX)==7,'a wall pin blocks the piece instead of crossing Mario through it')
  elseif mode=='rotate' then assert(r(N.player1_currentPiece)==18 and r(0x7801)==150,'rotation pushes Mario out of the occupied cells: '..r(N.player1_currentPiece)..' x '..r(0x7801)..' y '..r(0x7802))end
  screenshot('side-'..mode);finish('live piece side collision '..mode)
 end
end
