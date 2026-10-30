-- Replay the opening with controller input only. The jump at frame 572
-- hits the low brick ceiling; its bump must not send the global audio stop.
local f=0
local bumped=false
local audibleFrames=0
local melodyChanges=0
local lastMelody=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,right=f>500 and f<560,a=f>570 and f<605},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(a,v)
 if f>=500 and r(0xB6)==8 then
  assert((v&1)==0,'Mario sound effect sent Kid Icarus global audio-stop command')
  if r(0x68A7)==16 then
   assert(v==8,'Small Mario must use the native wall-bump sound')
   bumped=true
  end
 end
end,emu.callbackType.write,0x380)
emu.addMemoryCallback(function(a,v)
 if f>=620 and v~=lastMelody then
  melodyChanges=melodyChanges+1
  lastMelody=v
 end
end,emu.callbackType.write,0x4006)
emu.addEventCallback(function()
 f=f+1
 if f>=500 then
  assert(r(0xA0)==2,'Opening replay must remain in the first level')
  assert(r(0x38D)==1,'Opening level music stopped after a brick collision')
 end
 if f>=620 then
  local s=emu.getState()
  if (s['apu.square2.envelope.volume']>0 and s['apu.square2.envelope.lengthCounter.counter']>0)
   or (s['apu.triangle.linearCounter']>0 and s['apu.triangle.lengthCounter.counter']>0) then
   audibleFrames=audibleFrames+1
  end
 end
 if f==1200 then
  assert(bumped,'Controller replay must actually bump the brick ceiling')
  assert(audibleFrames>400,'Music channels must remain audible after the collision')
  assert(melodyChanges>10,'The melody must continue advancing after the collision')
  print(string.format('Opening brick bump retained music: %d audible frames, %d melody changes',audibleFrames,melodyChanges))
  emu.stop(0)
 end
end,emu.eventType.endFrame)
