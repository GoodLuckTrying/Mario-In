-- Start a real game after watching or cancelling an actual attract sequence.
-- No custom power/supply state is seeded: a new game must reset both itself.
local mode=END_MODE or 'start'
local coop=COOP or false
local phase='demo'
local f=0
local age=0
local demoFrames=0
local returned=false
local supplied=false
local flower=false
local fired=false
local liveFrames=0
local peakItems=0
local players=coop and 2 or 1
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local pad={}
 if phase=='cancel' then pad[mode]=true
 elseif phase=='choose' then
  pad.select=coop and age>=5 and age<8
  pad.start=age>=15 and age<18
 elseif phase=='play' then
  pad.right=supplied and not flower
  pad.b=flower and r(0x6035)==0
 end
 setPad(0,pad);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 if phase=='done' then return end
 f=f+1;age=age+1
 local game=r(N.GAME_ROUTINE_INDEX)
 local level=r(N.LEVEL_ROUTINE_INDEX)
 if phase=='demo' then
  if game==2 and level==4 then
   demoFrames=demoFrames+1
   if mode~='natural' and demoFrames>=400 then phase='cancel';age=0 end
  elseif demoFrames>0 and game==0 then phase='returning';age=0 end
 elseif phase=='cancel' then
  if age>=4 then phase='returning';age=0 end
 elseif phase=='returning' then
  if game==1 then phase='menu';age=0;returned=true end
  assert(age<120,'the demo must return to the menu after completion or cancellation')
 elseif phase=='menu' then
  if game==1 and r(N.HORIZONTAL_SCROLL)==0 then phase='choose';age=0 end
  assert(age<800,'the native title scroll must finish')
 elseif phase=='choose' then
  if age==10 then assert(r(N.PLAYER_MODE)==players-1,'select the requested native player mode')end
  if game==3 then phase='starting';age=0 end
  assert(age<80,'Start must leave the menu')
 elseif phase=='starting' then
  if game==5 and level==4 then
   for p=0,players-1 do
    assert(r(0x6004+p*128)==0,'player '..p..' must start small, without demo power')
    assert(r(0x604c+p*128)==0,'player '..p..' must receive a fresh supply allowance after the demo')
   end
   phase='play';age=0
  end
  assert(age<650,'the new game must reach live Jungle gameplay')
 elseif phase=='play' then
  assert(game==5 and level==4,'new gameplay must continue after the demo')
  liveFrames=liveFrames+1
  local all=true
  for p=0,players-1 do if r(0x604c+p*128)~=2 then all=false end end
  local items=0
  for i=0,15 do
   if r(N.ENEMY_ROUTINE+i)~=0 and r(N.ENEMY_TYPE+i)==0 and (r(N.ENEMY_ATTRIBUTES+i)&128)~=0 then items=items+1 end
  end
  peakItems=math.max(peakItems,items)
  if all then supplied=true end
  if r(0x6004)==2 then flower=true end
  if r(0x6180)>0 or r(0x6182)>0 then fired=true end
  if fired and liveFrames>=180 then
   assert(returned and supplied and peakItems>=players*2,'each new life must visibly spawn its two native supply items')
   print('PASS '..mode..' demo exit into '..players..' player game: starts small, '..peakItems..' visible supplies, collected flower and fired')
   phase='done'
   emu.stop(0)
  end
  assert(age<600,'new-game supplies must spawn and grant mushroom/flower power')
 end
 assert(f<6000,'demo exit, new game and supply pickup must complete')
end,emu.eventType.endFrame)
