local frame=0
local root=(TEST_ROOT..'/analysis/')
local log=assert(io.open(root..'player.csv','w'))
log:write('frame,mode,stage,screen,action,x,y,vx,vy,power,health\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function signed(a) local n=r(a); if n>=128 then return n-256 end; return n end
emu.addEventCallback(function()
  emu.setInput({start=frame==120, right=frame>=710 and frame<750, left=frame>=790 and frame<835,
    b=frame>=790 and frame<835, a=(frame>=880 and frame<910) or frame==1040,
    up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
  frame=frame+1
  if frame>=700 then
    log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%.4f,%.4f,%d,%d\n',frame,r(0x18),r(0x28),r(0x2f),r(0x46c),r(0x38c),r(0x3f),signed(0x6003)+r(0x6002)/256,signed(0x6005)+r(0x6004)/256,r(0x6001),r(0x45)))
  end
  if frame==740 or frame==898 or frame==1150 then
    local f=assert(io.open(root..'player-'..frame..'.png','wb')); f:write(emu.takeScreenshot()); f:close()
    local f=assert(io.open(root..'player-'..frame..'.ram','wb')); for a=0,0x7ff do f:write(string.char(r(a))) end; f:close()
  end
  if frame==1200 then log:close(); emu.stop(0) end
end,emu.eventType.endFrame)
