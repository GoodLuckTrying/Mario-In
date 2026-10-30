dofile(TEST_ROOT..'/tests/vs-common.lua')
local seeded=nil
local planned=false
local vertical=false
local last=nil
local gap=0
emu.addMemoryCallback(function()
 if not first or f-first<20 or seeded then return end
 seeded=f
 for y=0,19 do for x=0,9 do w(0x400+y*10+x,(y>=16 and x<9)and 0x7b or 0xef)end end
 w(N.levelNumber,0);w(N.lines,SEED_LINES or 0);w(N.currentPiece,18);w(N.tetriminoX,5);w(N.tetriminoY,0);w(N.playState,1)
 w(N.vramRow,0);w(N.player1_vramRow,0)
 w(0x7801,100);w(0x7802,176);w(0x7805,0);w(0x7806,0);w(0x7820,0);w(0x78b0,0)
end,emu.callbackType.exec,H.UpdateGate)
function tick(t)
 if not seeded then return end
 assert(r(0x780c)==0,'CPU Tetris in the opposite well must leave Mario safe')
 if r(0x78b0)==2 and r(0x78b5)==17 and r(0x78b6)==9 then planned=true end
 if r(N.player1_currentPiece)==17 and r(N.player1_tetriminoX)==9 then vertical=true end
 if r(N.player1_lines)==(SEED_LINES and 0x10 or 4)then
  assert(planned and vertical,'CPU must rotate and steer the selected I through native controls')
  assert(r(N.player1_score)==0 and r(N.player1_score+1)==(SEED_LINES and 0x24 or 0x12),'four-line clear keeps native scoring at the current level')
  assert(r(N.player1_levelNumber)==(SEED_LINES and 1 or 0),'CPU ten-line progress changes the actual current level')
  assert(r(N.lineClearStatsByType+3)==1,'a real Tetris updates native statistics')
  screenshot('vs-cpu-tetris');finish('CPU chooses, rotates, places and scores a four-line Tetris')
 end
 assert(f-seeded<500,'CPU must finish the available Tetris')
end
