if VS then HUMAN=true;dofile(TEST_ROOT..'/tests/vs-common.lua')else dofile(TEST_ROOT..'/tests/common.lua')end
local mode=MODE or 'stomp'
local seeded=nil
local killed=nil
local curtain=false
local standing=false
local rotated=false
local beforeSpawn=nil
local floorAgain=false
local function count()
 local n=0;for i=0,199 do if r(0x400+i)~=0xef then n=n+1 end end;return n
end
emu.addMemoryCallback(function()
 if first and f-first>=20 and not seeded then
  seeded=f
  for i=0,199 do w(0x400+i,0xef)end
  for a=0x7803,0x780b do w(a,0)end
  w(0x7807,0x70);w(0x7808,0x70)
  for a=0x7820,0x7825 do w(a,0)end
  -- Start the stomp approach close enough to pass ABOVE the column.
  -- The earlier x112 replay entered its side before hitting a lower cell.
  w(0x7801,(mode=='head' or mode=='stomp')and 128 or 100);w(0x7802,208)
  w(N.currentPiece,mode=='lock' and 17 or 18)
  w(N.tetriminoX,mode=='stomp' and 8 or mode=='lock' and 4 or 5)
  w(N.tetriminoY,mode=='stomp' and 17 or mode=='head' and 17 or mode=='lock' and 18 or 19)
  w(N.playState,(mode=='lock' or mode=='line')and 2 or 1)
  w(N.vramRow,0x20);w(N.player1_vramRow,0x20)
  w(N.fallTimer,mode=='head' and 48 or 0)
  w(N.autorepeatY,0)
  if VS then w(0x78a4,0);w(0x78a8,47)end
  if mode=='line' then for x=0,9 do if x<3 or x>6 then w(0x400+190+x,0x7b)end end end
  beforeSpawn=r(N.spawnCount)
 end
end,emu.callbackType.exec,H.UpdateGate)
function input(age)
 if not seeded then return{}end
 local t=f-seeded
 if mode=='stomp' then return{right=t>=1 and t<45 and r(0x7811)==0,a=t>=1 and t<32 and r(0x7811)==0}end
 if mode=='lock' then return{right=t>=3 and t<27,a=t>=3 and t<27}end
 return{}
end
emu.addMemoryCallback(function(a,v)
 if first and f-first>3 then
  local s=emu.getState()
  assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'gameplay VRAM writes must stay in vblank')
 end
end,emu.callbackType.write,0x2007)
function tick(age)
 if not seeded then return end
 local t=f-seeded
 if mode=='head' then
  if r(0x780c)>0 then killed=killed or f end
  if killed then
   assert(r(0x7802)<=209,'death must never wrap around the well')
   if r(N.player1_playState)==10 then curtain=true end
  end
  if t==350 then
   assert(killed and killed-seeded<=2,'a falling cell must hit Mario head on its next descent: killed '..tostring(killed)..' seeded '..seeded..' y '..r(N.player1_tetriminoY)..' dead '..r(0x780c))
   assert(curtain and r(0x780c)==80,'death must finish and start the native game-over curtain')
   screenshot('head-gameover');finish('falling head hit, finite Mario death and native game over')
  end
 elseif mode=='stomp' then
  if r(N.player1_currentPiece)==17 then rotated=true end
  assert(r(0x780c)==0,'controller jump onto a piece must stomp without head damage')
  if t==120 then
   assert(rotated and r(0x7811)==1 and r(0x7820)~=255,'A rotates the piece while Mario jumps onto it: rotated '..tostring(rotated)..' stomps '..r(0x7811)..' xy '..r(0x7801)..'/'..r(0x7802)..' piece '..r(N.player1_currentPiece))
   assert(count()==0 and r(N.spawnCount)~=beforeSpawn,'stomp removes the complete active piece, then spawns the next')
   assert(r(N.player1_lines)==0 and r(N.player1_score)==0,'stomps must not invent line-clear points')
   screenshot('stomp');finish('actual shared-controller jump, stomp, bounce, next piece and unchanged settled board/score')
  end
 elseif mode=='lock' then
  if r(0x7802)==176 and r(0x7820)==0 then standing=true end
  assert(r(0x780c)==0,'jumping onto a locked stack remains safe')
  if t==120 then
   assert(count()==4 and r(0x7811)==0 and standing,'locked piece stays solid and supports Mario after his jump: cells '..count()..' kills '..r(0x7811)..' standing '..tostring(standing)..' xy '..r(0x7801)..'/'..r(0x7802))
   screenshot('locked-platform');finish('native piece locking and jumping onto indestructible settled blocks')
  end
 elseif mode=='line' then
  assert(r(0x780c)==0,'native line clear must not kill the sheltered Mario')
  if t>20 and r(0x7802)==208 and r(0x7820)==0 then floorAgain=true end
  if t==150 then
   assert(r(N.player1_lines)==1 and r(N.player1_score)==0x40,'native single-line clearing must retain its 40-point score')
   assert(count()==0 and floorAgain,'cleared terrain disappears and Mario returns to the floor')
   screenshot('line-clear');finish('native line clear, score, redraw and Mario terrain support after the collapse')
  end
 end
end
