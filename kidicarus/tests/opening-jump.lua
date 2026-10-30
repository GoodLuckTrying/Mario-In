-- Exact opening softlock regression: no RAM writes, only controller input.
local f=0
local first=JUMP_FRAME or 270
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,a=f>=first and f<first+55 or f>=500 and f<525,
  right=f>=400 and f<460,left=f>=560 and f<620},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==375 then
  assert(r(0x720)>=160 and r(0x6805)==0,'The first jump must land back on the opening floor, not ground Mario inside the wall')
 end
 if f==460 then assert(r(0x723)>80,'Mario must be able to walk away after the opening jump') end
 if f==510 then assert(r(0x720)<175 and r(0x6818)>=128,'Mario must still be able to jump again') end
 if f==650 then
  assert(r(0x723)<110 and r(0xA0)==2 and (r(0x721)&0x40)==0,'Mario must still move left and remain alive after the opening jumps')
  print('Controller-only opening jump at frame '..first..' recovered: X='..r(0x723)..' Y='..r(0x720))
  emu.stop(0)
 end
end,emu.eventType.endFrame)
