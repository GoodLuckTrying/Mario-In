HUMAN=true
dofile(TEST_ROOT..'/tests/vs-common.lua')
local seeded=nil
local showing=nil
local rendered=false
local sawOldEdge=false
local resumed=nil
local snapshot=nil
local transitioning=false
emu.addMemoryCallback(function()transitioning=true end,emu.callbackType.exec,H.VResume)
function input(t)
 local dt=seeded and f-seeded or -1
 local ct=showing and f-showing or -1
 return {a=dt>=3 and dt<25 or not AUTO and not USE_START and ct==75,start=not AUTO and USE_START and ct==75}
end
emu.addMemoryCallback(function()
 if not first or f-first<20 or seeded then return end
 seeded=f
 for i=0,199 do w(0x400+i,0xef)end
 for x=0,2 do w(0x400+x,0x7b)end
 w(N.levelNumber,12);w(N.lines,0x27);w(N.lines+1,1)
 w(N.score,0x56);w(N.score+1,0x34);w(N.score+2,0x12)
 w(N.currentPiece,19);w(N.playState,9);w(N.vramRow,0);w(N.player1_vramRow,0)
 w(0x78ac,10);w(0x7801,100);w(0x7802,48);w(0x7805,0);w(0x7806,0);w(0x780b,0);w(0x7820,0)
end,emu.callbackType.exec,H.UpdateGate)
emu.addMemoryCallback(function()
 assert(sawOldEdge and r(0x7802)<=40,'Mario must jump eight pixels past the old exit before winning')
end,emu.callbackType.exec,H.VAdvance)
local function ppu(a)return emu.read(a,emu.memType.nesPpuDebug)end
emu.addMemoryCallback(function()
 if not first then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'clear-screen VRAM and bank changes require vblank or forced blank')
end,emu.callbackType.write,0x2007)
function tick(t)
 if not seeded then return end
 if r(0x7802)>40 and r(0x7802)<=48 and f-seeded>3 and r(0x78a3)==0 then sawOldEdge=true end
 if r(0x78ab)>0 then
  showing=showing or f
  if f-showing>=8 and not transitioning then
   assert(r(N.renderMode)==0 and r(0x78f1)==0,'round summary uses its own screen: render '..r(N.renderMode)..' bank '..r(0x78f1)..' timer '..r(0x78ab))
   assert(ppu(0x2156)==1 and ppu(0x2157)==2,'summary names the escaped level')
   assert(ppu(0x2196)==0 and ppu(0x2197)==2,'summary retains both Tetris level gains')
   assert(ppu(0x21d6)==1 and ppu(0x21d7)==3,'summary shows the next current level')
   for i,v in ipairs({1,2,7})do assert(ppu(0x2214+i)==v,'summary shows cumulative lines')end
   for i=1,6 do assert(ppu(0x2251+i)==i,'summary shows cumulative score')end
   assert(r(0x7801)==100 and r(0x7802)==208 and r(N.player1_currentPiece)==19,'Mario and pieces remain frozen during the summary')
   if not rendered then screenshot('round-clear-'..(AUTO and 'auto' or USE_START and 'start' or 'a'));rendered=true end
  end
 elseif showing and not resumed then
  resumed=f
  assert(rendered and r(N.renderMode)==3 and r(N.player1_levelNumber)==13,'resume restores gameplay at the earned next level')
  assert(r(N.player1_lines)==0x27 and r(N.player1_lines+1)==1 and r(N.player1_score+2)==0x12,'summary does not reset cumulative progress')
  if AUTO then assert(f-showing>=180,'automatic continuation leaves time to read')else assert(f-showing<100,'A/Start can continue after reading')end
 end
 if resumed and f-resumed==30 then
  assert(r(N.renderMode)==3 and r(0x780c)==0,'Start continuation must not immediately pause the new round')
  assert(r(0x78f1)==3 and r(0x78a0)==2,'native background and VS opponent are restored')
  finish('detailed clear summary, higher exit, persistent totals, and '..(AUTO and 'automatic' or USE_START and 'Start' or 'A')..' continuation')
 end
 assert(t<400,'round summary must resume cleanly')
end
