-- Controller shooting/movement plus hardware pose/gun synchronization.
local f=0
local checks=0
local recoils={0,0}
local ready={0,0}
local crouches={0,0}
local hidden={0,0}
local delayed=0
local swims={0,0}
local oldGraphics=nil
local expectedGun=dofile(TEST_ROOT..'/tests/rifle-expected.lua')
-- Attachment coordinates measured in the supplied PNG, also checked by
-- verify_sprites.py against execution of the assembled renderer.
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local seen={}
local oam=nil
emu.addEventCallback(function()
 for p=0,1 do
  local part=(f-950)%200
  setPad(p,{start=p==0 and (f==120 or f==200 or f==400),select=p==0 and f==180,
   right=f>=950 and not WATER and part<35,left=f>=950 and not WATER and part>=35 and part<70,
   down=f>=950 and not WATER and part>=130 and part<180,
   a=f>=950 and (WATER and f%60<15 or not WATER and part>=80 and part<105),
   b=f>=950 and f%12<4})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 if WATER then
  for a=0x680,0x6ff do w(a,0xaa)end
  for e=0,15 do w(N.ENEMY_ROUTINE+e,0);w(N.ENEMY_SPRITES+e,0)end
 end
 for p=0,1 do
  local b=0x6000+p*128
  w(b+4,POWER or math.floor((f-940)/200)%3);w(b+0x35,0);w(b+0x4c,2);w(b+0x49,240)
  if WATER and f<945 then w(N.SPRITE_Y_POS+p,200);w(b+5,2);w(b+0x18,1)end
  w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,(f>=1540 and f<1600)and 240 or 0)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>=1020 and f<1040 then
  oldGraphics=r(N.CPU_GRAPHICS_BUFFER);w(N.CPU_GRAPHICS_BUFFER,1);delayed=delayed+1
 end
end,emu.callbackType.exec,0x6500)
emu.addMemoryCallback(function()
 if oldGraphics~=nil then w(N.CPU_GRAPHICS_BUFFER,oldGraphics);oldGraphics=nil end
 if f<950 then return end
 oam={};for i=0,63 do oam[i]=r(0x6400+i)end
 for p=0,1 do
  local raw=r(0x6112+p);local pose=raw&63;local recoil=(raw&64)~=0
  assert(pose<27,'A valid uploaded player pose must own the rifle')
  seen[raw]=true
  local body=0x6410+p*16;local gun=0x6400+p*8
  if r(body)==0xf8 and r(body+8)==0xf8 or pose==22 or pose==25 then
   assert(r(gun)==0xf8 and r(gun+4)==0xf8,'Hidden/dead/morph players must have no detached rifle')
   hidden[p+1]=hidden[p+1]+1
  else
   local expected=expectedGun(raw,r(N.PLAYER_AIM_DIR+p),r(N.PLAYER_JUMP_STATUS+p)~=0,r(body+3),r(body),r(body+2))
   if expected.y<239 then
    assert(r(gun)==expected.y and r(gun+4)==expected.y,'The rifle must follow the uploaded body pose vertically: pose '..raw)
    assert(r(gun+3)==expected.x and r(gun+7)==expected.x2,'The rifle must follow the displayed body facing/position')
    assert(r(gun+1)==expected.tile and r(gun+5)==expected.second,'Ready/recoil/aim rifles must change with hardware CHR')
    assert(r(gun+2)==expected.attr and r(gun+6)==r(gun+2),'Rifles must keep native stage weapon colors and player priority')
    if recoil then recoils[p+1]=recoils[p+1]+1 else ready[p+1]=ready[p+1]+1 end
    if pose==26 then crouches[p+1]=crouches[p+1]+1 end
    if pose>=5 and pose<=9 or pose>=17 and pose<=21 then swims[p+1]=swims[p+1]+1 end
   end
  end
 end
 checks=checks+1
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1
 if oam then
  for i=0,63 do assert(emu.read(i,emu.memType.nesSpriteRam)==oam[i],'Body/fireball/rifle slots must reach hardware OAM intact')end
  oam=nil
 end
 if f==1008 then
  local suffix=WATER and '-water-'..POWER or ''
  local file=assert(io.open(TEST_ROOT..'/build/rifle-gameplay'..suffix..'.png','wb'));file:write(emu.takeScreenshot());file:close()
 end
 if f==1650 then
  for p=1,2 do
   assert(recoils[p]>20 and ready[p]>20,'Both players must show controller-driven firing and ready poses')
   if WATER then assert(swims[p]>200,'Both players must use the supplied swimming rifles')
   else assert(crouches[p]>5,'Small Mario and Luigi must use their supplied crouch art')end
   assert(hidden[p]>5,'Blinking must hide the whole player and rifle')
  end
  assert(checks>400 and delayed>=15,'Exercise sustained gameplay and deferred pose transfers')
  print('PASS '..checks..' hardware rifle frames, recoil '..recoils[1]..'/'..recoils[2]..', ready '..ready[1]..'/'..ready[2]..', deferred '..delayed)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
