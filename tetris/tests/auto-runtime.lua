MAX_FRAMES=MAX_FRAMES or 20000
dofile(TEST_ROOT..'/tests/auto-common.lua')
local last=nil
local gap=0
local updates=0
local pieces=0
local hunts=0
function input(t)return{left=true,right=t%2==0,a=true,b=true,down=true}end
function input2(t)return{right=true,a=true,down=true}end
emu.addMemoryCallback(function()
 if not first then return end
 if last then gap=math.max(gap,f-last)end
 last=f;updates=updates+1
end,emu.callbackType.exec,H.UpdateGate)
emu.addMemoryCallback(function()hunts=hunts+1 end,emu.callbackType.exec,H.AHunt)
emu.addMemoryCallback(function()
 if first then pieces=pieces+1 end
end,emu.callbackType.exec,N.incrementPieceStat)
local function transfer()
 if not first or f-first<3 then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'Auto background and CHR writes stay in vblank')
end
emu.addMemoryCallback(transfer,emu.callbackType.write,0x2007)
emu.addMemoryCallback(transfer,emu.callbackType.write,0xbfff)
function tick(t)
 if t<3 then return end
 assert(r(0x78a0)==3 and r(0x7800)~=0x4d,'Auto plays without Mario')
 assert(hunts==0 and r(0x78a3)==0 and r(0x78ab)==0,'Auto never hunts Mario or enters VS escape handling')
 assert(r(N.player1_playState)<10,'Auto survives a normal unassisted run')
 assert(emu.getState()['cpu.pc']>=0x6000,'Auto never executes data RAM')
 local oam=emu.memType.nesSpriteRam
 for i=0,252,4 do
  local tile=emu.read(i+1,oam)
  if emu.read(i,oam)<239 then assert(tile<0xf0 or tile>0xf3,'Mario tiles are absent from visible OAM')end
 end
 if t==(END_T or 8000)then
  assert(gap<=1 and updates>=t-1,'CPU planning updates every frame')
  assert(pieces>=30,'CPU repeatedly spawns and plays native pieces')
  assert(r(N.player1_lines)>0 or r(N.player1_lines+1)>0,'CPU earns native line clears on an unseeded board')
  screenshot('auto-runtime-'..(LEVEL or 0))
  finish('Auto-Classic survives and clears lines without Mario, human inputs or frame lag; '..pieces..' pieces')
 end
end
