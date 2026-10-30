-- Exercise each native exit and keep departed actors hidden until stage load.
local f=0
local stage=STAGE or 2
local exited=false
local finished=false
local hiddenFrames=0
local liftFrames=0
local transitioned=false
local fontChecked=false
local fontFile=assert(io.open(TEST_ROOT..'/tests/fixtures/lives-font.chr','rb'))
local font=fontFile:read('*a');fontFile:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(N.CURRENT_LEVEL,stage);w(N.LEVEL_ROUTINE_INDEX,0)end
 if f==950 then
  for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
  for a=N.BG_COLLISION_DATA,N.BG_COLLISION_DATA+127 do w(a,0)end
  for a=N.BG_COLLISION_DATA+12*4,N.BG_COLLISION_DATA+14*4-1 do w(a,0x55)end
  w(N.VERTICAL_SCROLL,0);w(N.HORIZONTAL_SCROLL,0);w(N.LEVEL_STOP_SCROLL,255);w(N.LEVEL_SCROLLING_TYPE,0)
  for p=0,1 do
   w(N.SPRITE_Y_POS+p,(stage==1 or stage==3) and 201 or 180);w(N.SPRITE_X_POS+p,80+p*80)
   w(N.PLAYER_HIDDEN+p,0);w(N.PLAYER_JUMP_STATUS+p,0);w(N.PLAYER_Y_FAST_VELOCITY+p,0);w(N.PLAYER_Y_FRACT_VELOCITY+p,0)
   w(0x6005+p*128,0);w(0x6018+p*128,0);w(0x6035+p*128,0);w(0x604C+p*128,2);w(0x6004+p*128,POWER or 2)
   w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0)
  end
  if stage==1 or stage==3 then w(N.LEVEL_LOCATION_TYPE,128)end
  w(N.BOSS_DEFEATED_FLAG,1)
 end
 if f>950 and r(N.CURRENT_LEVEL)==stage then
  if r(N.LEVEL_END_LVL_ROUTINE_STATE)==0 and r(N.PLAYER_HIDDEN)~=0 then exited=true end
  if exited and r(N.LEVEL_ROUTINE_INDEX)==9 then
   hiddenFrames=hiddenFrames+1
   assert(r(N.PLAYER_HIDDEN)~=0,'A departed actor must not reappear or wrap into the ending')
  end
  if r(N.BOSS_DEFEATED_FLAG)==2 then finished=true end
  if (stage==1 or stage==3) and r(N.PLAYER_STATE)==3 and r(N.SPRITE_Y_POS)>24 then
   liftFrames=liftFrames+1
   assert(r(N.CPU_SPRITE_BUFFER)==0x91,'Native elevator must remain under Mario')
  end
 end
 if finished and not fontChecked and r(N.CURRENT_LEVEL)==stage+1 and r(N.LEVEL_ROUTINE_INDEX)==2 and r(N.PPU_READY)==0 then
  assert(r(0x7920)==0 and r(N.PPUCTRL_SETTINGS)==0xb0,'stage lives screen releases title-only rendering')
  for i=0,0xf7f do assert(emu.read(0x1000+i,emu.memType.nesPpuMemory)==font:byte(i+1),'native font survives the next stage intro')end
  fontChecked=true
 end
 if finished and r(N.CURRENT_LEVEL)==stage+1 and r(N.LEVEL_ROUTINE_INDEX)==4 then
  transitioned=true
  assert(r(0x604C)==2 and r(0x60CC)==2,'A stage transition must not duplicate life supplies')
  assert(r(0x6004)==(POWER or 2),'Mario power must survive the exit')
  assert(hiddenFrames>40,'The departure must remain hidden through the full ending delay')
  assert(fontChecked,'verify the intermediate lives screen before playing the next stage')
  if stage==1 or stage==3 then assert(liftFrames>80,'Both native base elevators must complete their ride')end
  print('PASS native exit '..stage..', hidden '..hiddenFrames..' frames, lift '..liftFrames..', next level playable')
  emu.stop(0)
 end
 assert(f<2600,'Native exit must reach the next playable stage')
end,emu.eventType.endFrame)
