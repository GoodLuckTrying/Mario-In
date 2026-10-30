-- Replay the trailer's exact movement/combat/rope sequence. Verify the
-- original deformable rope patterns every displayed frame, beyond the
-- shared oracle's periodic audit, including both human choices.
dofile(TEST_ROOT..'/tests/game.lua')
local file=assert(io.open(TEST_ROOT..'/build/native-background-reference.bin','rb'))
local reference=file:read('*a');file:close()
local frames=0;local ropeFrames=0
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first or mode()~=0xABFF then return end
 for i=0x830,0xc2f do
  assert(emu.read(0x1000+i,emu.memType.nesPpuDebug)==reference:byte(1025+i),'deformable rope pixels stay native at frame '..(f-first))
 end
 local used=false
 for a=0x2180,0x23bf do
  local tile=emu.read(a,emu.memType.nesPpuDebug)
  if tile>=0x83 and tile<=0xc2 then used=true;break end
 end
 if used then ropeFrames=ropeFrames+1 end
 frames=frames+1
end,emu.callbackType.exec,0xADFE)
local gameTick=tick
function tick(t)
 if t==850 then
  assert(frames>=840 and ropeFrames>20,'exercise actual displayed deformed rope tiles: '..frames..' frames, '..ropeFrames..' rope frames')
 end
 gameTick(t)
end
