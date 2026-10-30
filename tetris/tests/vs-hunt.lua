LEVEL=LEVEL or 19
dofile(TEST_ROOT..'/tests/vs-common.lua')
local mode=MODE or 'track'
local seeded=nil
local firstLeft=false
local minX=5
local laterRight=false
local diverted=false
local dodged=false
local last=nil
local maxGap=0
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return {right=mode=='track' and dt>=10 and dt<45,b=mode=='track' and dt>=10 and dt<45}
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
 w(N.levelNumber,LEVEL);w(N.currentPiece,10);w(N.tetriminoX,mode=='corner' and 9 or 5);w(N.tetriminoY,(mode=='dodge' or mode=='corner')and 8 or 4);w(N.playState,1)
 w(N.vramRow,0x20);w(N.player1_vramRow,0x20);w(N.fallTimer,0);w(N.autorepeatY,0)
 w(0x78a4,0);w(0x78a8,0);w(0x78b0,3);w(0x78b5,10);w(0x78b6,5);w(0x78b8,8);w(0x78c6,r(0x78a9))
 for a=0x7b10,0x7b1c do w(a,0)end
 w(0x7801,mode=='track' and 120 or mode=='dodge' and 132 or 160);w(0x7802,(mode=='dodge' or mode=='corner')and 100 or 208)
 if mode=='dodge' or mode=='corner' then w(0x7820,2);w(0x7805,2)end
 if mode=='divert' then w(0x400+4*10+6,0x7b)end
 for col=0,9 do w(0x7900+col,mode=='divert' and col==6 and 4 or 20)end
 w(0x7b1d,r(0x78a9))
end,emu.callbackType.exec,H.UpdateGate)
emu.addMemoryCallback(function()
 if not seeded then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'active AI decisions keep background transfers in vblank')
end,emu.callbackType.write,0x2007)
function tick(t)
 if not seeded then return end
 local dt=f-seeded
 assert(r(0x780c)==0,'pursuit/dodge opening must leave Mario alive')
 if r(0x7811)==0 then assert(r(N.player1_tetriminoY)>=4,'active pursuit must never teleport the piece back to spawn')end
 if mode=='track' then
  if dt<30 then minX=math.min(minX,r(N.player1_tetriminoX))end
  if dt<10 and r(N.player1_tetriminoX)<5 then firstLeft=true end
  if dt>30 and r(N.player1_tetriminoX)>minX then laterRight=true end
  if LEVEL<10 then assert(r(N.player1_tetriminoX)==5,'level nine sticks to its Tetris plan')end
 elseif mode=='divert' and dt<10 and r(N.player1_tetriminoX)<5 then diverted=true
 elseif mode=='dodge' and r(N.player1_tetriminoX)>=7 then dodged=true end
 if dt==(mode=='track' and 60 or mode=='divert' and 12 or 10)then
  assert(maxGap<=1 and last>=f-1,'pursuit and safety evaluation fit one update per frame: gap '..maxGap..' last '..tostring(last)..' frame '..f)
  if mode=='track' and LEVEL>=10 then assert(firstLeft and laterRight,'one committed falling piece follows Mario as he changes sides')
  elseif mode=='divert' then assert(diverted,'the CPU diverts when direct pursuit is blocked')
  elseif mode=='corner' then assert(r(0x7811)==1,'Mario can still stomp the CPU when there is no safe dodge')
  elseif mode=='dodge' then assert(dodged and r(0x7811)==0,'the CPU moves far enough to evade an approaching stomp')end
  screenshot('hunt-'..mode..'-'..LEVEL);finish('active CPU '..mode..' at level '..LEVEL)
 end
end
