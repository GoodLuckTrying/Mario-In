local f=0
local booted=false
local stage=STAGE or 0
local swapped=false
local writes=0
local bad=0
local dma=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4,right=f>700 and f<800,a=f>730 and f<760,b=f>700 and f<800})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if swapped then return end
 swapped=true;w(0x31,stage)
end,emu.callbackType.exec,0xC6B5)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if f>650 and r(0x98)==0 then
  writes=writes+1
  if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then bad=bad+1 end
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function(a,v)
 if v==0x64 then dma=dma+1 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1
 if swapped and r(0x4d0)>=128 then booted=true end
 if f>650 then w(0x5e,121) end
 if f==900 then
  print('stage '..stage..' ready '..r(0x6982)..' bank '..r(0xF2)..' dma '..dma..' video '..writes..'/'..bad)
  assert(swapped and r(0x31)==stage and dma>100,'Native stage must load and draw Mario')
  assert(writes>100 and bad==0,'Stage graphics stay in vblank')
  local o=io.open(TEST_ROOT..'/build/stage-'..stage..'.png','wb');o:write(emu.takeScreenshot());o:close()
  print('PASS stage '..stage);emu.stop(0)
 end
end,emu.eventType.endFrame)
