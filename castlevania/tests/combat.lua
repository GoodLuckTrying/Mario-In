local frame=0
local root=(TEST_ROOT..'/analysis/')
local log=assert(io.open(root..'combat.csv','w'))
log:write('frame,mode,stage,screen,action,x,y,vx,vy,power,health,bump,pickup,itemx,itemy,kind,fire1,fire2,stomps,firehits\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function signed(a) local n=r(a); if n>=128 then return n-256 end; return n end
emu.addEventCallback(function()
  emu.setInput({start=frame==120, right=(frame>=710 and frame<747) or (frame>=850 and frame<939) or (frame>=1400 and frame<2400),
    b=frame==1140 or (frame>=1400 and frame%15~=0), a=(frame>=790 and frame<820) or (frame>=990 and frame<1020) or (frame>=1600 and frame%100<30), up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
  frame=frame+1
  if frame>=700 then
    log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%.4f,%.4f,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,r(0x18),r(0x28),r(0x2f),r(0x46c),r(0x38c),r(0x3f),signed(0x6003)+r(0x6002)/256,signed(0x6005)+r(0x6004)/256,r(0x6001),r(0x45),r(0x6044),r(0x6047),r(0x390),r(0x358),r(0x60a4),r(0x6020),r(0x6021),r(0x6045),r(0x6046)))
  end
  if frame==740 or frame==898 or frame==1600 or frame==1800 or frame==2200 or frame==2500 then
    local f=assert(io.open(root..'combat-'..frame..'.png','wb')); f:write(emu.takeScreenshot()); f:close()
    local f=assert(io.open(root..'combat-'..frame..'.ram','wb')); for a=0,0x7ff do f:write(string.char(r(a))) end; f:close()
  end
  if frame==2600 then
    assert(r(0x18)==5 and r(0x28)>=1, "Castle transition must continue gameplay")
    assert(r(0x6046)>0, "Fireballs must hit native enemies")
    
    log:close(); emu.stop(0)
  end
end,emu.eventType.endFrame)
