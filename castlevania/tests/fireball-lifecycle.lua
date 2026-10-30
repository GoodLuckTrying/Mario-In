local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120,b=frame==701 or frame==703 or (frame>=705 and frame<721)},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame>=700 then for x=3,23 do w(0x434+x,0);w(0x60a0+x,0) end end
 if frame==700 then w(0x6001,2);w(0x6020,0);w(0x6021,0) end
 if frame==730 or frame==740 or frame==760 then
  w(0x6020,1);w(0x6021,0);w(0x602c,frame==730 and 2 or 100);w(0x6022,120);w(0x6024,frame==760 and 183 or 80);w(0x6026,frame==760 and 2 or 0);w(0x6050,frame==760 and 64 or 0);w(0x6028,frame==760 and 128 or 0);w(0x602a,0)
  if frame==740 then w(0x49,253) end
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame==704 then assert(r(0x6020)==1 and r(0x6021)==1,'Two fireballs must spawn') end
 if frame==706 then assert(r(0x602c)==95 and r(0x602d)==97,'Third press must not replace an active fireball') end
 if frame==721 then assert(r(0x602c)==80 and r(0x602d)==82,'Holding B must not spawn extra fireballs') end
 if frame==732 then assert(r(0x6020)==0 and r(0x355)==244,'Expired fireball must hide its sprite') end
 if frame==741 then assert(r(0x6022)==121,'Fireball must follow one camera delta then move four pixels') end
 if frame==761 then
  assert(r(0x6024)==184 and r(0x6026)==253 and r(0x6050)==144 and r(0x6028)==192,'Floor bounce must snap correctly and retain the SMB fractional motion')
  print('Fireball capacity, button edge, lifetime, camera and bounce passed');emu.stop(0)
 end
end,emu.eventType.endFrame)
