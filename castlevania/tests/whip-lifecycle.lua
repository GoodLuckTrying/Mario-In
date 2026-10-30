-- Actual button edges plus controlled power, rendering and transition fixtures.
local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=frame==120,b=(frame>=700 and frame<726) or frame==800 or frame==860,up=frame==860},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame>=700 then for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end end
 if frame==700 or frame==800 then
  w(0x603e,0);w(0x6039,0);w(0x6001,frame==700 and 0 or 2);w(0x600d,0);w(0x5b,0);w(0x46c,0)
  w(0x450,frame==700 and 0 or 1);w(0x6020,0);w(0x6021,0)
 end
 if frame==860 then w(0x603e,0);w(0x6001,2);w(0x15b,8);w(0x71,20);w(0x64,0);w(0x434,0);w(0x46c,2);w(0x6020,0);w(0x6021,0) end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then assert(r(0x603e)==24 and r(0x6040)==24,'B must start a small whip swing') end
 if frame==705 then assert(r(0x6160)==4,'Small windup must draw body plus whip') end
 if frame==714 then
  assert(r(0x6160)==5,'Small whip must draw three horizontal segments')
  local f=assert(io.open((TEST_ROOT..'/analysis/whip-small.png'),'wb'));f:write(emu.takeScreenshot());f:close()
 end
 if frame==726 then assert(r(0x603e)==0,'Holding B must not restart the whip');print('Small B swing, rendering and hold behavior passed') end
 if frame==801 then assert(r(0x603e)==24 and r(0x6040)==40 and r(0x6020)==1,'Fire Mario must whip and shoot on the same B press') end
 if frame==805 then assert(r(0x6160)==6,'Big windup must draw body plus whip') end
 if frame==814 then
  assert(r(0x6160)==9,'Grown whip must draw five horizontal segments')
  local f=assert(io.open((TEST_ROOT..'/analysis/whip-big.png'),'wb'));f:write(emu.takeScreenshot());f:close()
  print('Grown B swing and simultaneous fireball passed')
 end
 if frame==861 then
  assert(r(0x603e)==0 and r(0x6020)==0 and r(0x6021)==0,'Up+B must not start a whip or fireball')
  print('Up+B remains reserved for native subweapons');emu.stop(0)
 end
 if frame==900 then print('FAIL missing whip lifecycle');emu.stop(1) end
end,emu.eventType.endFrame)
