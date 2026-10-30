dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil;local hit=nil;local queued=nil;local checks=0
local colors=CHAR==3 and{0x30,0x27,0x19}or{0x16,0x27,0x18}
local function ppu(a)return emu.read(a,emu.memType.nesPpuDebug)end
emu.addMemoryCallback(function()
 if not seeded then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'palette refresh stays inside vblank or forced blank')
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 w(H.PlayerHealth,31);w(H.PlayerCurrentSize,0);w(H.PlayerState,0);w(H.DamageInvulnTime,0)
 w(H.PlayerXLo,120);w(H.PlayerXVelocity,0);w(H.PlayerInAir,0)
 for _,a in ipairs({H.ObjectTimer1,H.ObjectTimer2,H.ObjectStunTimer,H.ObjectFlashTimer,H.ObjectProjectileTimer,H.ObjectBeingCarriedTimer,H.ObjectXAcceleration,H.ObjectYAcceleration,H.EnemyCollision,H.EnemyVariable,H.ObjectXVelocity,H.ObjectYVelocity})do w(a,0)end
 w(H.EnemyState,1);w(H.ObjectType,1);w(H.EnemyRawDataOffset,255)
 w(H.ObjectXLo,130);w(H.ObjectXHi,r(H.PlayerXHi));w(H.ObjectYLo,(r(H.PlayerYLo)+16)&255);w(H.ObjectYHi,r(H.PlayerYHi))
 w(H.EnemyArray_46E,0);w(H.EnemyArray_492,5);w(H.ObjectHitbox,2);w(H.EnemyHP,0)
end,emu.callbackType.exec,H.HandlePlayerState)
emu.addMemoryCallback(function()if seeded then hit=hit or f end end,emu.callbackType.exec,H.DamagePlayer)
emu.addMemoryCallback(function()
 if not hit or f-hit<90 or queued or r(H.PlayerState)~=0 then return end
 assert(r(H.PlayerCurrentSize)==1 and r(H.PlayerHealth)==15,'a real enemy hit shrinks the player')
 for i=1,3 do assert(ppu(0x3f10+i)==colors[i],'shrinking initially applies regular Small colors')end
 -- Native screen/palette buffers can be uploaded after their producer has
 -- already invalidated the cache. Reproduce that delayed upload through
 -- the real NMI buffer reader, without writing PPU memory from the test.
 local a=H.PPUBuffer_301
 for i,v in ipairs({0x3f,0x11,3,r(H.RestorePlayerPalette0+1),r(H.RestorePlayerPalette0+2),r(H.RestorePlayerPalette0+3),0})do w(a+i-1,v)end
 w(H.ScreenUpdateIndex,0);queued=f
end,emu.callbackType.exec,H.WaitForNMI)
function input(t)return{}end
function tick(t)
 if not queued then return end
 if f>queued+2 then
  assert(r(H.PlayerCurrentSize)==1 and r(H.PlayerHealth)==15,'palette refresh preserves Small form and health')
  for i=1,3 do assert(ppu(0x3f10+i)==colors[i],'native palette reload must not leave Small Mario/Luigi in Fire colors')end
  checks=checks+1
 end
 if checks==30 then finish('real shrink and delayed native palette upload retain regular Small colors')end
 assert(f-queued<80,'palette reload check completes')
end
