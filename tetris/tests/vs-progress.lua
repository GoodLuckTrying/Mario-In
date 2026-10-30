HUMAN=true
dofile(TEST_ROOT..'/tests/vs-common.lua')
local seed=false
local earned=false
local ready=false
local jumped=nil
local escaped=nil
local continued=false
local function boardClear()
 for i=0,199 do w(0x400+i,0xef)end
 w(N.vramRow,0x20);w(N.player1_vramRow,0x20)
end
function input(t)
 return {a=jumped and f-jumped<25}
end
emu.addMemoryCallback(function()
 if not first or f-first<20 then return end
 if not seed then
  seed=true;boardClear()
  for x=0,9 do if x<3 or x>6 then w(0x400+190+x,0x7b)end end
  w(N.lines,9);w(N.levelNumber,0);w(N.currentPiece,18);w(N.tetriminoX,5);w(N.tetriminoY,19);w(N.playState,2)
  w(0x7801,100);w(0x7802,208)
 elseif earned and not ready then
  ready=true;boardClear()
  -- The fixture is a reachable high platform; actual A input crosses
  -- the top boundary and runs the round reset through normal gameplay.
  for x=0,2 do w(0x400+40+x,0x7b)end
  w(N.currentPiece,19);w(N.playState,9)
  w(0x7801,100);w(0x7802,80);w(0x7805,0);w(0x7806,0);w(0x780b,0);w(0x7820,0)
  jumped=f+2
 elseif escaped and not continued and f-escaped>40 then
  continued=true;boardClear()
  for x=0,9 do if x<3 or x>6 then w(0x400+190+x,0x7b)end end
  w(N.lines,0x19);w(N.currentPiece,18);w(N.tetriminoX,5);w(N.tetriminoY,19);w(N.playState,2)
  w(0x7801,100);w(0x7802,208);w(0x7805,0);w(0x7806,0);w(0x7820,0)
 end
end,emu.callbackType.exec,H.UpdateGate)
emu.addMemoryCallback(function()
 if first then
  local s=emu.getState()
  assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not s['ppu.mask.backgroundEnabled'],'VS transfers stay inside vblank: '..string.format('%04x',s['cpu.pc'])..' scanline '..s['ppu.scanline']..' clear '..r(0x78ab)..' render '..r(N.renderMode))
 end
end,emu.callbackType.write,0x2007)
function tick(t)
 if t<3 then return end
 assert(r(0x780c)==0,'scoring and escaping must leave Mario alive')
 if not earned and r(N.player1_levelNumber)==1 and r(N.player1_lines)==0x10 then earned=true end
 if r(0x78a3)==1 and not escaped then
  escaped=f
  assert(earned and ready,'a native line-based level was earned before the actual jump')
  assert(r(N.player1_levelNumber)==2,'escape advances one beyond the current earned level')
  assert(r(N.player1_lines)==0x10,'escape keeps earned lines permanently')
  assert(r(0x7802)==208 and r(0x7801)==100,'new round respawns Mario on the empty floor')
  for i=0,199 do assert(r(0x400+i)==0xef,'escape clears the whole logical board')end
 end
 if continued and r(N.player1_levelNumber)==3 and r(N.player1_lines)==0x20 then
  assert(r(0x78a0)==2 and r(0x78a3)==1,'round clear retains VS opponent and counts the escape once')
  screenshot('vs-progress');finish('VS native level gain, controller top exit, board reset, permanent progress and another ten-line level')
 end
 assert(t<500,'VS progress must complete')
end
