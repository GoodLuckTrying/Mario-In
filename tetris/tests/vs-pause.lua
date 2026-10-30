HUMAN=HUMAN or false
dofile(TEST_ROOT..'/tests/vs-common.lua')
local captured=nil
function input(t)return {start=t==50 or t==110,right=t>60 and t<100,a=t>60 and t<100}end
function input2(t)return{down=true,left=t>60 and t<100,a=t>60 and t<100}end
function tick(t)
 if t==58 then
  captured={}
  for _,a in ipairs({0x7801,0x7802,0x78b0,0x78b3,0x78a4,0x78a8,N.player1_tetriminoX,N.player1_tetriminoY,N.player1_currentPiece})do captured[a]=r(a)end
 end
 if t>60 and t<105 then
  assert(r(N.renderMode)==0,'P1 Start pauses both VS opponents')
  for a,v in pairs(captured)do assert(r(a)==v,'Mario, pieces, AI search and reaction timers freeze while paused')end
 end
 if t==140 then assert(r(N.renderMode)==3,'P1 Start resumes VS');finish('VS pause freezes Mario, pieces, search and warning clocks')end
end
