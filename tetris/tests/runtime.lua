dofile(TEST_ROOT..'/tests/common.lua')
local minY=208
local maxX=0
local minX=255
local turns=0
local lastPiece=nil
local checks=0
local frames=assert(io.open(TEST_ROOT..'/build/mario-frames.chr','rb')):read('*a')
local poses={23,12,13,14,16,22,15}
local original=assert(io.open('C:/nes/Tetris (USA).nes','rb')):read('*a')
local seen={}
local expectedOam=nil
function input(age)
 return {right=age>=5 and age<30,left=age>=35 and age<80,a=age>=90 and age<114,b=age>=130 and age<134}
end
emu.addMemoryCallback(function(a,v)
 if not first or f-first<2 or r(N.renderMode)~=3 then return end
 local s=emu.getState()
 assert(s['ppu.mask.backgroundEnabled'] and s['ppu.mask.spritesEnabled'],'the gameplay display must remain enabled')
 local pose=r(0x780d);local bank=r(0x78f2)
 assert(bank==4+pose,'Mario CHR must follow the staged pose')
 for i=0,63 do assert(emu.read(0xf00+i,emu.memType.nesPpuDebug)==frames:byte(poses[pose+1]*128+65+i),'hardware Mario CHR must match SMB1')end
 for i=0,4095 do assert(emu.read(0x1000+i,emu.memType.nesPpuDebug)==original:byte(0xb011+i),'the native background CHR must remain exact')end
 assert(emu.read(0x3f1d,emu.memType.nesPpuDebug)==0x16 and emu.read(0x3f1e,emu.memType.nesPpuDebug)==0x27 and emu.read(0x3f1f,emu.memType.nesPpuDebug)==0x18,'Mario palette must retain SMB colors')
 expectedOam={};local marioCells=0
 for i=0,252,4 do
  local tile=r(0x201+i)
  if tile>=0xf0 and tile<=0xf3 and (r(0x202+i)&3)==3 then
   assert(r(0x200+i)>=47 and r(0x200+i)<208,'Mario sprite cells remain in the gameplay area')
   for n=0,3 do expectedOam[i+n]=r(0x200+i+n)end
   marioCells=marioCells+1
  end
 end
 assert(marioCells==4,'all four Mario body tiles must be staged')
 seen[pose]=true;checks=checks+1
end,emu.callbackType.write,0x4014)
-- Serial CHR changes must complete while the beam is outside active video.
emu.addMemoryCallback(function(a,v)
 if not first or f-first<3 then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'CHR animation must switch during vblank')
end,emu.callbackType.write,0xbfff)
function tick(age)
 if age<2 then return end
 if expectedOam then
  for i,v in pairs(expectedOam)do assert(emu.read(i,emu.memType.nesSpriteRam)==v,'Mario body must reach hardware OAM')end
  expectedOam=nil
 end
 local x=r(0x7801);local y=r(0x7802)
 assert(x>=96 and x<=160 and y>=64 and y<=208,'Mario stays inside the well')
 assert(r(0x780c)==0,'opening controller sequence stays alive')
 minX=math.min(minX,x);maxX=math.max(maxX,x);minY=math.min(minY,y)
 local piece=r(N.player1_currentPiece)
 if lastPiece and piece~=lastPiece then turns=turns+1 end
 lastPiece=piece
 if age==240 then
  assert(minX==96 and maxX>112 and minY<180 and turns>=2,'shared controls must move Mario, jump, and rotate the piece both ways')
  assert(checks>200 and seen[0] and seen[4] and (seen[1]or seen[2]or seen[3]),'walking, idle and jumping graphics reach hardware')
  screenshot(TYPE_B and 'type-b' or 'type-a')
  finish('shared controls, Mario bounds, SMB graphics/palette, unchanged native background and vblank animation')
 end
end
