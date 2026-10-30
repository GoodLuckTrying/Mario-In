dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local damaged=false
local nativeKill=0
local collision=0
emu.addMemoryCallback(function()if seeded then collision=collision+1 end end,emu.callbackType.exec,H.MarioFireCollision)
emu.addMemoryCallback(function()if seeded then nativeKill=nativeKill+1 end end,emu.callbackType.exec,H.HandleMonsterDied)
emu.addMemoryCallback(function()
 if not first or f-first<10 or seeded then return end
 seeded=f
 for i=1,12 do w(H.ObjType+i,0);w(H.ObjMetastate+i,0)end
 for i=0,703 do w(0x6530+i,0x26)end
 w(H.ObjX,112);w(H.ObjY,141);w(H.ObjDir,1);w(H.ObjState,0);w(H.ObjGridOffset,0)
 w(H.Items,0);w(H.InvClock,1)
 local i=1
 w(H.ObjType+i,8);w(H.ObjX+i,168);w(H.ObjY+i,141);w(H.ObjDir+i,2)
 w(H.ObjHP+i,16);w(H.ObjAttr+i,0);w(H.ObjUninitialized+i,0);w(H.ObjInvincibilityMask+i,0);w(H.ObjInvincibilityTimer+i,0)
 w(H.ObjAnimCounter+i,6);w(H.ObjState+i,0);w(H.ObjQSpeedFrac+i,0x20)
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)return{a=seeded and f-seeded==5}end
function tick(t)
 if not seeded then return end
 damaged=damaged or r(H.ObjHP+1)==0
 assert(r(H.HeartValues)==0x22,'Mario fire never hurts its owner')
 if f-seeded==100 then
  assert(collision>0 and nativeKill>0 and damaged,'A fireball defeats an actual Octorock through native damage/death logic')
  assert(r(H.Items)==0,'fireballs work before collecting a sword')
  finish('sword-free A fireball, real enemy collision, native death and friendly ownership')
 end
end
