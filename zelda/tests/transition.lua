dofile(TEST_ROOT..'/tests/common.lua')
local room=nil
local sawShot=false
local entered=nil
local transitions=0
emu.addMemoryCallback(function()if first then transitions=transitions+1 end end,emu.callbackType.exec,H.ResetPlayerState)
function input(t)
 if not room then room=r(H.RoomId)end
 return{up=not entered,a=t==5}
end
function tick(t)
 if t<0 then return end
 sawShot=sawShot or r(0x7fc0)>0 or r(0x7fc1)>0
 if room and r(H.RoomId)~=room and r(H.GameMode)==5 and r(H.IsUpdatingMode)==1 then entered=entered or f end
 if entered and f-entered==20 then
  assert(sawShot and transitions>0,'a real room transition follows a fired shot')
  assert(r(0x7fc0)==0 and r(0x7fc1)==0,'shots never carry over or wrap into the next room')
  assert(emu.read(0x580,emu.memType.nesPpuDebug)~=0 or emu.read(0x581,emu.memType.nesPpuDebug)~=0,'fireball CHR survives native scrolling')
  screenshot('next-room');finish('native room scrolling, fire reset and preserved projectile patterns')
 end
 assert(t<700,'walk into the native next room')
end
