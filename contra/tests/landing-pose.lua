-- Real opening jump/landing with the player upload delayed as it is by
-- native terrain transfers; the native graphics command itself is restored
-- before its reader runs. Mario must keep walking and never upload a
-- queued jump after that jump has already ended.
local p=PLAYER or 0
local b=0x6000+p*128
local f=0
local sawAir=false
local landed=nil
local released=false
local originalGraphics=nil
local checked=0
local movedFrom=nil
local groundUpdates=0
local done=false
local jumpFrame=nil
local stableGround=0
local frames=assert(io.open(TEST_ROOT..'/build/mario-frames.chr','rb')):read('*a')
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function world()return r(N.LEVEL_SCREEN_NUMBER)*256+r(N.LEVEL_SCREEN_SCROLL_OFFSET)+r(N.SPRITE_X_POS+p)end
emu.addEventCallback(function()
 local move=jumpFrame~=nil and f>=jumpFrame
 for q=0,1 do setPad(q,{start=q==0 and (f==120 or f==200 or f==400),select=q==0 and f==180,right=move,b=move,a=q==p and move and f<jumpFrame+25})end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=600 and emu.getState()['cpu.x']==p then
  w(b+4,POWER or 0);w(b+0x35,0);w(b+0x4c,2);w(b+0x49,255);w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0)
  if landed then groundUpdates=groundUpdates+1 end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if jumpFrame~=nil and f>=jumpFrame and sawAir and not released then
  if landed and groundUpdates>=5 then released=true
  else originalGraphics=r(N.CPU_GRAPHICS_BUFFER);w(N.CPU_GRAPHICS_BUFFER,1)end
 end
end,emu.callbackType.exec,0x6500)
emu.addMemoryCallback(function()
 if originalGraphics~=nil then w(N.CPU_GRAPHICS_BUFFER,originalGraphics);originalGraphics=nil end
 if released and r(b+5)==0 and r(b+0x47)==0 then
  local pose=r(0x6112+p)
  assert((pose&0x3f)~=4 and (pose&0x3f)~=16,'a delayed jump graphic must not upload after landing: player '..p..' f '..f..' pose '..pose..' desired '..r(b+0x1f))
  assert(r(N.PLAYER_STATE+p)==1,'the landing must remain in live native gameplay')
  for i=0,127 do
   assert(emu.read(0x280+p*128+i,emu.memType.nesPpuDebug)==frames:byte(pose*128+i+1),'the recovered pose must reach actual CHR RAM')
  end
  checked=checked+1
 end
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 if jumpFrame~=nil and f>=jumpFrame and r(N.LEVEL_ROUTINE_INDEX)==4 then
  local s=emu.getState();assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240,'pose refresh must stay in vblank')
 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 -- Wait for both opening spawn falls to finish before testing a jump.
 -- A fixed video frame can still be part of the native entrance after a
 -- longer title/font load, causing two simultaneous landings instead.
 if not jumpFrame and r(N.GAME_ROUTINE_INDEX)==5 and r(N.LEVEL_ROUTINE_INDEX)==4
  and r(N.PLAYER_STATE)==1 and r(N.PLAYER_STATE+1)==1 and r(0x6005)==0 and r(0x6085)==0 then
  stableGround=stableGround+1
  if stableGround>=5 then jumpFrame=f+3 end
 elseif not jumpFrame then stableGround=0 end
 if jumpFrame and f>=jumpFrame and r(b+5)==1 then sawAir=true end
 if sawAir and not landed and r(b+5)==0 then landed=f;movedFrom=world()end
 if released and checked>=20 then
  assert(sawAir and landed and groundUpdates>=5,'exercise an actual controller jump and landing while uploads wait')
  assert(world()>movedFrom+10,'ground movement must continue while animation catches up: start '..movedFrom..' end '..world()..' landing '..landed..' now '..f..' state '..r(b+5)..' speed '..r(b+6))
  print('PASS player '..p..' power '..(POWER or 0)..' native opening jump/landing: pending graphics stay current; ground movement continues; '..checked..' post-landing DMA checks')
  done=true;emu.stop(0)
 end
 assert(f<1150,'opening landing and pose recovery must finish')
end,emu.eventType.endFrame)
