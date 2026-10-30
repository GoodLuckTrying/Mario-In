local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local log=assert(io.open((TEST_ROOT..'/analysis/gate-small.csv'),'w'))
log:write('frame,mode,stage,x,world,y,action,dir,face,speed,force,camera,frac,flags,power\n')
emu.addEventCallback(function() emu.setInput({start=frame==120,right=frame>=710,b=frame>=710},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then w(0x6001,0) end
 if frame>700 then w(0x600d,90) end
 if frame>=700 then log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,r(0x18),r(0x28),r(0x38c),r(0x40)+256*r(0x41),r(0x3f),r(0x46c),r(0x3c),r(0x450),r(0x6071),r(0x6072),r(0x2e)+256*r(0x2f),r(0x2d),r(0x142),r(0x6001))) end
 if frame==1300 then log:close();emu.stop(0) end
end,emu.eventType.endFrame)
