local f=0;local raster=0;local frames=0;local started=false
local references={}
for i=0,4 do local file=assert(io.open(TEST_ROOT..'/build/title-expected-'..i..'.rgb','rb'));references[i]=file:read('*a');file:close()end
local displayed={0,0}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
local function expect_screen(mode)
 local fb=emu.getScreenBuffer()
 for y=0,239 do for x=0,255 do
  local rx,ry=x,y
  if mode==1 and x>=16 and x<24 then
   if y>=152 and y<168 then rx,ry=0,0
   elseif y>=168 and y<184 then ry=y-16 end
  end
  local state=x<200 and displayed[1] or displayed[2]
  local reference=references[state==0 and 0 or x<200 and state or state+2]
  local at=(ry*256+rx)*3+1
  local expected=(reference:byte(at)<<16)|(reference:byte(at+1)<<8)|reference:byte(at+2)
  assert((fb[y*256+x+1]&0xffffff)==expected,'whole supplied title image, mode '..mode..' pixel '..x..','..y)
 end end
 frames=frames+1
end
emu.addMemoryCallback(function()
 displayed={r(0x7927),r(0x7928)}
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function(a,v)
 if v==0xb0 and r(0x7920)==1 and r(N.PPU_READY)==0 then
  local st=emu.getState();local scan=st['ppu.scanline'];local dot=st['ppu.cycle']
  assert(scan==127 and dot>=300 or scan==128 and dot<50,'title background bank changes at the safe split, got '..scan..':'..dot)
  raster=raster+1
 end
end,emu.callbackType.write,0x2000)
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200,select=f==180});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==100 then
  assert(r(N.GAME_ROUTINE_INDEX)==1 and r(0x7920)==1,'cold boot reaches supplied title')
  expect_screen(0)
  local out=assert(io.open(TEST_ROOT..'/build/title-player-one.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==190 then
  assert(r(N.PLAYER_MODE)==1,'Select still chooses two players')
  expect_screen(1)
  local out=assert(io.open(TEST_ROOT..'/build/title-player-two.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if r(N.GAME_ROUTINE_INDEX)==5 and r(N.LEVEL_ROUTINE_INDEX)==4 then started=true end
 if f==850 then
  assert(started and r(N.PLAYER_MODE)==1,'Start enters a real two-player game')
  assert(r(0x7920)==0,'gameplay releases all title-only rendering')
  assert(raster>150 and frames==2,'repeated safe split and complete pixel checks')
  print('PASS all 61440 supplied title pixels in both player modes, safe raster/CHR/OAM, movable mushroom cursor and native two-player start')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
