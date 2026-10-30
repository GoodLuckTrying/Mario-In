dofile(TEST_ROOT..'/tests/common.lua')
local step=0;local armed=false;local ret=nil;local start=nil
local highSpeed=nil;local airSpeed=nil;local capFrames=0
function input(age)
 if age<10 then return{}end
 -- The second, standing jump selects $70 fall force. At top running
 -- speed SMB1 selects $90, whose cap has no nonzero fractional frame.
 return{right=step<60,b=step<60,a=(step>=60 and step<85)or(step>=200 and step<225)}
end
local function after()
 if not armed then return end
 armed=false
 if step==59 then highSpeed=r(0x7821)end
 if step==65 then airSpeed=r(0x7821);assert(r(0x7820)~=0,'neutral-input sample is airborne')end
 if r(0x7805)==4 then
  if r(0x7806)~=0 then capFrames=capFrames+1 end
 end
 step=step+1
 if step==300 then
  assert(highSpeed==40 and airSpeed==40,'neutral airborne controls retain SMB1 momentum')
  assert(capFrames>0,'the replay must reach SMB1 fractional terminal descent')
  print('MEASURE Tetris run and neutral-air speed both '..highSpeed..'/16; fractional SMB1 descent preserved')
  finish('live Tetris air coasting and fractional fall cap match SMB1')
 end
end
emu.addMemoryCallback(function()
 if not first or f-first<10 or done then return end
 if not ret then
  local sp=emu.getState()['cpu.sp'];ret=r(0x100+sp+1)+256*r(0x100+sp+2)+1
  emu.addMemoryCallback(after,emu.callbackType.exec,ret)
 end
 if not start then
  start=f
  for a=0x7800,0x7831 do w(a,0)end
  w(0x7800,0x4d);w(0x7801,128);w(0x7802,208);w(0x7807,0x70);w(0x7808,0x70)
  w(0x7826,1);w(0x7827,1);w(0x782f,1);w(0x7830,8)
 end
 -- Keep the camera/terrain fixture centered, without changing velocity.
 w(0x7801,128)
 for a=0x400,0x4c7 do w(a,0xef)end
 w(N.currentPiece,19);w(N.playState,1)
 armed=true
end,emu.callbackType.exec,H.Step)
