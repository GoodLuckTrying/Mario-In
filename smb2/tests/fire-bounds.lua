-- Isolate screen edges in real horizontal/vertical rooms, retaining the
-- native projectile initialization, physics, tile/object collision and OAM.
local wrapping=MODE=='wrap-left' or MODE=='wrap-right'
local vertical=MODE=='top' or MODE=='bottom' or MODE=='bottom-edge' or MODE=='y-page'
local verticalRoom=wrapping or vertical
AREA=verticalRoom and 1 or 2
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local started=false
local updates=0
local renders=0
local destroyed=0
local expected=nil
local slot=nil
local camera=MODE=='page' and 240 or 0
local cameraY=MODE=='y-page' and 240 or 0
local expectedY=nil
local left=MODE=='left' or MODE=='spawn-left' or MODE=='wrap-left'
local exits=MODE~='page' and MODE~='y-page' and not wrapping
local function position(lo,hi,value)
 w(lo,value&255);w(hi,(value>>8)&255)
end
local function view()
 position(H.ScreenBoundaryLeftLo,H.ScreenBoundaryLeftHi,camera)
 position(H.ScreenBoundaryRightLo,H.ScreenBoundaryRightHi,camera+255)
 position(H.ScreenYLo,H.ScreenYHi,cameraY)
end
emu.addMemoryCallback(function()
 if not first or f-first<130 then return end
 if not seeded then
  seeded=f
  assert(r(H.IsHorizontalLevel)==(verticalRoom and 0 or 1),'fixture loads the native room orientation')
  for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
  for i=0,2399 do w(0x6000+i,0x40)end
  for page=0,9 do for col=0,15 do w(0x6000+page*240+160+col,0xd5)end end
 end
 w(H.PlayerHealth,31);w(H.PlayerCurrentSize,0);w(H.PlayerState,0)
 w(H.PlayerDucking,0);w(H.PlayerInAir,0);w(H.PlayerXVelocity,0);w(H.PlayerYVelocity,0)
 position(H.PlayerXLo,H.PlayerXHi,camera+120)
 position(H.PlayerYLo,H.PlayerYHi,128)
end,emu.callbackType.exec,H.HandlePlayerState)
emu.addMemoryCallback(function()
 if not seeded then return end
 view()
 local x=camera+120
 if MODE=='spawn-left' then x=camera+2 end
 if MODE=='spawn-right' then x=camera+250 end
 position(H.PlayerXLo,H.PlayerXHi,x)
 w(H.PlayerDirection,left and 0 or 1)
end,emu.callbackType.exec,H.MarioFireSpawn_Create)
emu.addMemoryCallback(function()
 if not seeded then return end
 view()
 slot=r(H.byte_RAM_12)
 if not started then
  started=true
  if MODE=='page' then
   position(H.ObjectXLo+slot,H.ObjectXHi+slot,255)
  elseif MODE=='left' or MODE=='right' or wrapping then
   position(H.ObjectXLo+slot,H.ObjectXHi+slot,left and 1 or 254)
   -- Vertical shots can be created with a carried/underflowed page; the
   -- native wrapping room must normalize it before screen bounds checks.
   if MODE=='wrap-left' then w(H.ObjectXHi+slot,255)end
  end
  position(H.ObjectYLo+slot,H.ObjectYHi+slot,vertical and (MODE=='top' and 0 or MODE=='bottom-edge' and 230 or 255) or 128)
  w(H.ObjectYVelocity+slot,vertical and (MODE=='top' and 0xd0 or 0x30) or 0)
  w(H.ObjectYSubpixel+slot,0)
  w(H.ObjectXVelocity+slot,vertical and 0 or left and 0xd0 or 0x30)
  w(H.ObjectXSubpixel+slot,0)
 end
 local before=r(H.ObjectXLo+slot)+256*r(H.ObjectXHi+slot)
 expected=verticalRoom and ((before+(vertical and 0 or left and -3 or 3))&255) or ((before+(left and -3 or 3))&65535)
 local vy=r(H.ObjectYVelocity+slot)
 if vy>=128 then vy=vy-256 end
 expectedY=(r(H.ObjectYLo+slot)+256*r(H.ObjectYHi+slot)+math.floor((r(H.ObjectYSubpixel+slot)+vy*16)/256))&65535
 updates=updates+1
end,emu.callbackType.exec,H.MarioFireBehavior)
emu.addMemoryCallback(function()
 if not started then return end
 renders=renders+1
 assert(not exits,'an offscreen shot is destroyed before rendering or object collision')
 assert(r(H.SpriteTempScreenX)==((expected-camera)&255),'render position uses the current full world position')
 assert(r(H.SpriteTempScreenY)==((expectedY-cameraY-1)&255),'vertical render position uses the current world position and camera')
 local y=emu.getState()['cpu.y']
 assert(y and r(H.SpriteDMAArea+3+y)==((expected-camera)&255),'actual fireball OAM stays at its visible position')
end,emu.callbackType.exec,H.MarioFireRender_Exit)
emu.addMemoryCallback(function()if started then destroyed=destroyed+1 end end,emu.callbackType.exec,H.MarioFireDestroy)
function input(t)return{b=seeded and f-seeded==5}end
function tick(t)
 if not started then return end
 if exits then
  assert(destroyed==1 and renders==0,'non-wrapping edges remove shots on their first offscreen update')
  assert(r(H.EnemyState+slot)==0 and r(0x7e40+slot)==0,'despawning releases the object slot and two-shot allowance')
  finish('fireball '..MODE..' despawns without an opposite-edge sprite')
 elseif updates>=8 then
  assert(destroyed==0 and renders==updates,'visible page crossings and native wrap stay alive')
  assert(r(H.ObjectXLo+slot)+256*r(H.ObjectXHi+slot)==expected,'native movement keeps the correct world coordinate')
  assert(r(H.ObjectYLo+slot)+256*r(H.ObjectYHi+slot)==expectedY,'vertical page crossing stays inside the viewport')
  finish('fireball '..MODE..' keeps native movement and correct OAM for eight updates')
 end
end
