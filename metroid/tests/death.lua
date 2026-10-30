-- Damage/death must reach the original game-over/password flow without reset.
local f=0
local entered=nil
local seeded=false
local sawDead=false
local sawDead2=false
local password=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,right=t>=30 and t<45});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()if not entered then entered=f end end,emu.callbackType.exec,H.BeforeHandler)
emu.addMemoryCallback(function()
 if r(0x23)==1 then for i=0,5 do w(0x6af4+i*16,0)end end
end,emu.callbackType.exec,N.UpdateWorld)
emu.addMemoryCallback(function()
 if not entered or f-entered~=100 then return end
 w(0x106,0x10);w(0x107,0);w(0x70,0);w(0x30a,0);w(0x6c8d,0)
 w(0x6af4,2);w(0x6af5,8);w(0x6af6,8);w(0x6afb,r(0x30c));w(0x6b02,5)
 w(0x400,r(0x30d));w(0x401,(r(0x30e)+4)&255);w(0x40b,2);w(0x40f,0);w(0x404,0)
 seeded=true
end,emu.callbackType.exec,N.CollisionDetection)
emu.addMemoryCallback(function()assert(not entered,'gameplay must not jump to reset')end,emu.callbackType.exec,0xFFB0)
emu.addMemoryCallback(function()assert(not entered,'gameplay must not restart at Startup')end,emu.callbackType.exec,N.Startup)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<1600,'native start');return end
 if r(0x300)==7 then sawDead=true end
 if r(0x300)==8 then sawDead2=true end
 if sawDead2 and r(0x1d)==1 and r(0x23)==0 and r(0x1f)>=0x19 then password=true end
 if password then
  assert(seeded and sawDead and sawDead2,'native death animation stages')
  assert(r(H.M_MAGIC)==77,'private state survives normal game over')
  local out=assert(io.open(TEST_ROOT..'/build/password-after-death.png','wb'));out:write(emu.takeScreenshot());out:close()
  print('PASS native injury, death animation and game-over/password progression without reset')
  emu.stop(0)
 end
 assert(f-entered<1100,'death must finish and enter native password flow')
end,emu.eventType.endFrame)
