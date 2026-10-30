dofile(TEST_ROOT..'/tests/vs-common.lua')
local pieces={}
local frames=0
local lastUpdate=nil
local maxGap=0
local firstX=nil
function input(t)
 if HUMAN then return {right=t>=5 and t<30,a=t>=45 and t<65}end
 return {}
end
function input2(t)
 if HUMAN then return {left=t>=80 and t<84,b=t==100,down=t>=110}end
 return {left=true,down=true,a=true} -- CPU must ignore P2.
end
emu.addMemoryCallback(function()
 if not first then return end
 if lastUpdate then maxGap=math.max(maxGap,f-lastUpdate)end
 lastUpdate=f;frames=frames+1
 -- Shelter Mario to isolate a long CPU native-board run.
 if not HUMAN then
  w(0x7801,96);w(0x7802,208);w(0x7805,0);w(0x7806,0);w(0x7820,0);w(0x780c,0)
 end
end,emu.callbackType.exec,H.UpdateGate)
local function vblankWrite()
 if not first or f-first<3 then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'VS background and CHR writes stay inside vblank')
end
emu.addMemoryCallback(vblankWrite,emu.callbackType.write,0x2007)
emu.addMemoryCallback(vblankWrite,emu.callbackType.write,0xbfff)
if not HUMAN then
 emu.addMemoryCallback(function()w(0x7801,0)end,emu.callbackType.exec,H.Contacts)
 emu.addMemoryCallback(function()w(0x7801,96)end,emu.callbackType.exec,H.DrawGate)
end
function tick(t)
 if t<2 then return end
 assert(emu.getState()['cpu.pc']>=0x6000,'VS must never execute data RAM')
 assert(r(0x78a0)==(HUMAN and 2 or 1),'real VS menu selects the requested opponent')
 if not firstX then firstX=r(N.player1_tetriminoX)end
 if HUMAN and t==75 then
  assert(r(0x7801)>112,'P1 controls Mario')
  assert(r(N.player1_tetriminoX)==firstX,'P1 movement and jump cannot move or rotate pieces')
 end
 if HUMAN and t==105 then
  assert(r(N.player1_tetriminoX)<firstX,'P2 controls the piece independently')
  screenshot('vs-human')
 end
 if t==120 then pieces[1]=r(N.statsByType)end
 if t==(HUMAN and 110 or END_T or 2200)then
  if HUMAN then assert(r(0x780c)==0,'the independent-controller opening stays alive')
  else
   local occupied=0
   for i=0,199 do if r(0x400+i)~=0xef then occupied=occupied+1 end end
   assert(occupied>=8 or r(N.player1_lines)>0,'CPU places pieces and plays real Tetris')
   assert(r(N.player1_playState)<10,'CPU must not top out Mario')
   assert(maxGap<=1,'CPU search must not cause frame lag')
   assert(frames>=t-1 and lastUpdate>=f-1,'CPU and Mario updates must stay live for the entire run')
   if END_T then assert(r(N.lineClearStatsByType+3)>0,'a normal CPU round must actually earn four-line Tetrises')end
  end
  screenshot(HUMAN and 'vs-human-final' or 'vs-cpu')
  finish(HUMAN and 'VS human menu and independent controller roles' or 'VS CPU menu, native placements, fair route and one update per frame')
 end
end
