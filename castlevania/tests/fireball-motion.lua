local frame=0
local isSMB=false
local root=(TEST_ROOT..'/analysis/')
local log=assert(io.open(root..(isSMB and 'smb-fireball.csv' or 'hybrid-fireball.csv'),'w'))
log:write('tick,x,y,vhi,vlo,yfrac,active\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then
  if isSMB then
   w(0x756,2)
   w(0x24,1);w(0x25,0);w(0x8d,64);w(0x74,0);w(0xd5,112);w(0xbc,1);w(0x5e,64);w(0xa6,4);w(0x43a,0);w(0x41d,0);w(0x4a0,7)
  else
   w(0x6020,1);w(0x6021,0);w(0x6022,64);w(0x6024,112);w(0x6026,4);w(0x6050,0);w(0x6028,0);w(0x602a,0);w(0x602c,100)
  end
 end
 if frame>700 and frame<=720 then
  if isSMB then
   for x=0,5 do w(0xf+x,0) end
   log:write(string.format('%d,%d,%d,%d,%d,%d,%d\n',frame-700,r(0x8d),r(0xd5),r(0xa6),r(0x43a),r(0x41d),r(0x24)))
  else
   log:write(string.format('%d,%d,%d,%d,%d,%d,%d\n',frame-700,r(0x6022),r(0x6024),r(0x6026),r(0x6050),r(0x6028),r(0x6020)))
  end
 end
 if frame==720 then log:close();emu.stop(0) end
end,emu.eventType.endFrame)
if not isSMB then emu.addMemoryCallback(function() if frame>=700 then for x=3,23 do w(0x434+x,0);w(0x60a0+x,0) end end end,emu.callbackType.exec,0xcf19) end
