HUMAN=true
dofile(TEST_ROOT..'/tests/vs-common.lua')
local seeded=nil
local pending=false
function input(t)return {a=seeded and f-seeded>=15 and f-seeded<40}end
emu.addMemoryCallback(function()
 if not first or f-first<20 or seeded then return end
 seeded=f
 for i=0,199 do w(0x400+i,0xef)end
 for x=0,2 do w(0x400+x,0x7b)end
 w(N.vramRow,0);w(N.player1_vramRow,0)
 w(N.currentPiece,19);w(N.playState,9);w(N.levelNumber,0)
 w(0x7801,100);w(0x7802,48);w(0x7805,0);w(0x7806,0);w(0x780b,0);w(0x7820,0)
end,emu.callbackType.exec,H.UpdateGate)
if DURING_SCORE then
 emu.addMemoryCallback(function()
  if seeded and f-seeded==15 then
   w(N.playState,5);w(N.completedLines,1);w(N.lines,9)
  end
 end,emu.callbackType.exec,H.UpdateGate)
end
function tick(t)
 if not seeded then return end
 if f-seeded<15 then
  assert(r(0x78a3)==0 and r(0x7802)==48,'being raised to the roof is not a win until Mario jumps out')
 end
 if r(0x78a7)==1 and r(N.player1_levelNumber)==1 then pending=true end
 if r(0x78a3)==1 then
  assert(r(N.player1_levelNumber)==(DURING_SCORE and 2 or 1),'escape includes a pending native level-up')
  if DURING_SCORE then assert(pending and r(N.player1_lines)==0x10,'line scoring finishes before the round reset')end
  finish(DURING_SCORE and 'top exit during scoring preserves the earned level before advancing' or 'standing at the roof requires an actual jump to escape')
 end
 assert(f-seeded<100,'a top-edge jump must advance once')
end
