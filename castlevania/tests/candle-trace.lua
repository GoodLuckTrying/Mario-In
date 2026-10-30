local frame=0
local root=(TEST_ROOT..'/analysis/')
local log=assert(io.open(root..'candle-trace.csv','w'))
log:write('frame,mode,stage,screen,action,x,y,vx,vy,power,health,bump,pickup,itemx,itemy,kind,fire1,fire2\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function signed(a) local n=r(a); if n>=128 then return n-256 end; return n end
emu.addEventCallback(function()
  emu.setInput({start=frame==120, right=(frame>=710 and frame<747) or (frame>=850 and frame<939),
    b=frame==1140, a=(frame>=790 and frame<820) or (frame>=990 and frame<1020), up=false,down=false,select=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
  frame=frame+1
  if frame>=1000 then
    for i=3,22 do
      if r(0x434+i)>=40 or r(0x60a0+i)>0 then
        log:write(string.format('actor,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,i,r(0x434+i),r(0x38c+i),r(0x354+i),r(0x300+i),r(0x31c+i),r(0x488+i),r(0x60a0+i),r(0x60e0+i)))
      end
    end
  end
  if frame>=700 then
    log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%.4f,%.4f,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,r(0x18),r(0x28),r(0x2f),r(0x46c),r(0x38c),r(0x3f),signed(0x6003)+r(0x6002)/256,signed(0x6005)+r(0x6004)/256,r(0x6001),r(0x45),r(0x6044),r(0x6047),r(0x390),r(0x358),r(0x60a4),r(0x6020),r(0x6021)))
  end
  if frame==740 or frame==898 or frame==1143 or frame==1150 then
    local f=assert(io.open(root..'candles-'..frame..'.png','wb')); f:write(emu.takeScreenshot()); f:close()
    local f=assert(io.open(root..'candles-'..frame..'.ram','wb')); for a=0,0x7ff do f:write(string.char(r(a))) end; f:close()
  end
  if frame==1800 then
    assert(r(0x6044)>=2, "Both candles must bump")
    assert(r(0x6047)>=2 and r(0x6001)==2, "Mushroom and flower must upgrade Mario")
    log:close(); emu.stop(0)
  end
end,emu.eventType.endFrame)
