dofile(TEST_ROOT..'/tests/auto-common.lua')
MODE=MODE or 'tetris'
local seeded=nil
local planned=false
local vertical=false
local topout=nil
local captured=nil
local returned=nil
local fresh=nil
function input(t)
 if MODE=='pause' then return{start=t==50 or t==110,left=t>60 and t<100,a=t>60 and t<100}end
 if MODE=='reset' then return{a=t>=40 and t<45,b=t>=40 and t<45,select=t>=40 and t<45,start=t>=40 and t<45}end
 if MODE=='topout' and topout then return{start=t%60==20}end
 return{}
end
function input2(t)return{right=true,down=true,a=true}end
emu.addMemoryCallback(function()
 if not first or f-first<20 or seeded or MODE=='pause' or MODE=='reset' then return end
 seeded=f
 for y=0,19 do for x=0,9 do
  local filled=MODE=='topout' or (y>=16 and x<9)
  w(0x400+y*10+x,filled and 0x7b or 0xef)
 end end
 w(N.levelNumber,LEVEL or 0);w(N.lines,SEED_LINES or 0)
 for i=0,2 do w(N.score+i,0)end
 w(N.currentPiece,18);w(N.tetriminoX,5);w(N.tetriminoY,0);w(N.playState,1)
 w(N.vramRow,0);w(N.player1_vramRow,0);w(0x78b0,0)
end,emu.callbackType.exec,H.UpdateGate)
emu.addMemoryCallback(function()
 if first and MODE=='reset' then fresh=f end
end,emu.callbackType.exec,H.SessionGate)
function tick(t)
 if t<3 then return end
 if MODE~='reset' then assert(r(0x7800)~=0x4d,'Auto never initializes Mario')end
 if MODE=='pause' then
  if t==58 then
   captured={}
   for _,a in ipairs({0x78b0,0x78b3,N.player1_tetriminoX,N.player1_tetriminoY,N.player1_currentPiece})do captured[a]=r(a)end
  end
  if t>60 and t<105 then
   assert(r(N.renderMode)==0,'Start pauses Auto-Classic')
   for a,v in pairs(captured)do assert(r(a)==v,'CPU search and pieces freeze during pause')end
  end
  if t==140 then assert(r(N.renderMode)==3,'Start resumes Auto-Classic');finish('Auto native pause and resume')end
 elseif MODE=='reset' then
  if r(N.gameMode)<4 then returned=returned or f end
  if returned then
   -- Common input has already started; drive menus again with Start.
   function input(age)return{start=f%90<4}end
  end
  if fresh and returned and r(N.gameMode)==4 and r(0x7800)==0x4d then
   assert(r(0x78a0)==0,'reset leaves Auto and starts a fresh Solo game')
   finish('Auto native reset returns to mode selection and restores Solo Mario')
  end
 elseif seeded then
  if MODE=='topout' then
   if r(N.player1_playState)>=10 then topout=topout or f end
   if topout and r(N.gameMode)==3 then
    assert(r(0x78a0)==3,'native game over retains Auto for another attempt')
    finish('Auto blocked spawn uses native game-over curtain and returns to level selection')
   end
  else
   if r(0x78b0)==2 and r(0x78b5)==17 and r(0x78b6)==9 then planned=true end
   if r(N.player1_currentPiece)==17 and r(N.player1_tetriminoX)==9 then vertical=true end
   if r(N.player1_lines)==(SEED_LINES and 0x10 or 4)then
    local level=LEVEL or 0
    assert(planned and vertical,'CPU rotates and steers the I through native controls')
    assert(r(N.lineClearStatsByType+3)==1,'native Tetris statistic increments')
    assert(r(N.player1_levelNumber)==(level==0 and SEED_LINES and 1 or level),'Auto keeps native starting-level progression rules')
    assert(r(0x78a3)==0 and r(0x78ab)==0,'Auto cannot complete a Mario VS round')
    screenshot('auto-tetris-'..level)
    finish('Auto native four-line clear, scoring and classic level progression')
   end
  end
  assert(f-seeded<700,'Auto native fixture completes: mode '..r(N.gameMode)..' phase '..r(N.player1_playState)..' curtain '..r(N.player1_curtainRow))
 end
end
