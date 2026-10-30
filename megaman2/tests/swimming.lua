local f=0
local entered=nil
local wet=0
local strokes=0
local previousA=false
local minSpeed=255
local maxSpeed=0
local seededRun=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()if r(0x29)==13 then w(0x2a,1)end end,emu.callbackType.exec,N.stage_select_loop)
-- Start at the game's real underwater checkpoint, using its complete native
-- room/camera/CHR loader rather than fabricating collision or water tiles.
emu.addMemoryCallback(function()w(N.checkpoint_idx,1)end,emu.callbackType.exec,N.checkpoint_respawn)
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 local swim=r(0x702d)~=0 and entered
 local a=(swim and wet%40<2)or(not swim and t>30 and t%60<25)
 setPad(0,{start=not entered and f%120<3,right=t>30 and not swim,b=t>30 and not swim,a=a});setPad(1,{})
 if a and not previousA then strokes=strokes+1 end
 previousA=a
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x29)~=14 then return end
 if not entered then entered=f;assert(r(0x2a)==3,'Bubble Man stage through native menu')end
 if not seededRun and r(0x2c)>=3 and r(0x2c)<9 and r(0x702f)==1 and r(0x702d)==0 then
  -- An approaching run reaches a real water tile. The adapter must discard
  -- its excessive dry-land speed before applying this swimming update.
  w(H.M_SMB_X_SPEED,40);w(H.M_SMB_X_FORCE,255);w(0x480,255);seededRun=true
 end
 for i=16,31 do w(0x420+i,0)end
end,emu.callbackType.exec,H.Motion)
emu.addEventCallback(function()
 f=f+1
 if entered and r(0x702d)~=0 then
  wet=wet+1
  local vx=r(H.M_SMB_X_SPEED);if vx>=128 then vx=256-vx end
  maxSpeed=math.max(maxSpeed,vx);minSpeed=math.min(minSpeed,vx)
  assert(vx<=16,'running speed must not carry into swimming')
  assert(r(0x700e)==0,'native water selects SMB swimming physics')
  if wet==70 then local out=assert(io.open(TEST_ROOT..'/build/swimming.png','wb'));out:write(emu.takeScreenshot());out:close()end
 end
 if entered and (f-entered)%300==0 then print('W f='..f..' stage='..r(0x2a)..' XY='..r(0x460)..','..r(0x4a0)..' water='..r(0x702f)..' row='..r(0x33)..' screen='..r(0x440)..' state='..r(H.M_STATE));local out=assert(io.open(TEST_ROOT..'/build/water-route.png','wb'));out:write(emu.takeScreenshot());out:close()end
 if wet==160 then
  assert(strokes>=4,'fresh A presses swim upwards')
  assert(seededRun,'exercise running-to-water transition')
  assert(r(0x6c0)>0,'water movement remains playable')
  print('PASS Bubble Man native water: '..wet..' updates, '..strokes..' strokes, speed '..maxSpeed..'/16 px, swimming art')
  emu.stop(0)
 end
 assert(f<4000,'route must reach native water; wet='..wet)
end,emu.eventType.endFrame)
