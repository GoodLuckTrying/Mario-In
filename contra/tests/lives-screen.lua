-- Cold start or an actual attract-mode return, then the complete native lives UI.
local f=0;local age=0;local phase=AFTER_DEMO and 'demo'or 'menu'
local demoFrames=0;local checked=false;local gameplay=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local file=assert(io.open(TEST_ROOT..'/tests/fixtures/lives-jungle-'..(COOP and 'coop'or 'solo')..'.rgb','rb'))
local reference=file:read('*a');file:close()
file=assert(io.open(TEST_ROOT..'/tests/fixtures/lives-font.chr','rb'));local font=file:read('*a');file:close()
emu.addEventCallback(function()
 local buttons={}
 if phase=='menu'then buttons.start=age==120 or age==200;buttons.select=COOP and age==180 end
 setPad(0,buttons);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1;age=age+1
 local game=r(N.GAME_ROUTINE_INDEX);local level=r(N.LEVEL_ROUTINE_INDEX)
 if phase=='demo'then
  if game==2 and level==4 then demoFrames=demoFrames+1 end
  if demoFrames>100 and game==1 then phase='menu';age=0 end
 end
 -- Scores flash with the native frame counter. Compare the complete screen
 -- during its visible phase, which can shift after an attract sequence.
 if not checked and game==5 and level==2 and r(N.DELAY_TIME_LOW_BYTE)<140
  and emu.read(0x208b,emu.memType.nesPpuMemory)==0x30 then
  assert(not AFTER_DEMO or demoFrames>100,'watch a real demo before starting')
  assert(r(N.PLAYER_MODE)==(COOP and 1 or 0),'selected native player count')
  assert(r(0x7920)==0 and r(N.PPUCTRL_SETTINGS)==0xb0,'release the title sprite/raster state before lives text')
  local fb=emu.getScreenBuffer()
  for y=0,239 do for x=0,255 do
   local at=(y*256+x)*3+1
   local expected=(reference:byte(at)<<16)|(reference:byte(at+1)<<8)|reference:byte(at+2)
   assert((fb[y*256+x+1]&0xffffff)==expected,'native lives-screen pixel '..x..','..y)
  end end
  -- Native graphic_data_01 restores tiles $00..$F7. Its final eight tiles
  -- are outside the font transfer and are not used by the lives screen.
  for i=0,0xf7f do assert(emu.read(0x1000+i,emu.memType.nesPpuMemory)==font:byte(i+1),'restore original lives font tile byte '..i)end
  local tag=(COOP and 'coop'or 'solo')..(AFTER_DEMO and '-after-demo'or '-fresh')
  local out=assert(io.open(TEST_ROOT..'/build/lives-verified-'..tag..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  checked=true
 end
 if checked and game==5 and level==4 then
  print('PASS complete original lives-screen pixels/font and playable '..(COOP and 'two-player'or 'solo')..(AFTER_DEMO and ' start after actual demo'or ' cold start'))
  emu.stop(0)
 end
 assert(f<4500,'lives screen and playable game must complete')
end,emu.eventType.endFrame)
