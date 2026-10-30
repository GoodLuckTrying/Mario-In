dofile(TEST_ROOT..'/tests/common.lua')
local captured=nil
local resumes=false
function input(age)
 return{start=age>=40 and age<44 or age>=90 and age<94,right=age>=45 and age<85,a=age>=50 and age<80}
end
function tick(age)
 if age==48 then captured={r(0x7801),r(0x7802),r(N.player1_tetriminoX),r(N.player1_tetriminoY),r(N.player1_currentPiece)}end
 if age>=50 and age<88 then
  assert(r(N.renderMode)==0,'Start must invoke native pause')
  assert(r(0x7801)==captured[1] and r(0x7802)==captured[2],'Mario freezes during pause')
  assert(r(N.player1_tetriminoX)==captured[3] and r(N.player1_tetriminoY)==captured[4] and r(N.player1_currentPiece)==captured[5],'paused controller input cannot move or rotate pieces')
 end
 if age==130 then assert(r(N.renderMode)==3,'Start must resume normal gameplay');finish('native pause freezes Mario and Tetris, then resumes')end
end
