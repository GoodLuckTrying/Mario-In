local f=0
local stage=STAGE or 0
local live=0
local splits=0
local updates=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{start=f>=200 and f<210,a=f>600});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function() if f>600 then splits=splits+1 end end,emu.callbackType.exec,0x9ab2)
emu.addMemoryCallback(function() if f>=600 and f<900 then updates=updates+1 end end,emu.callbackType.exec,0x80b3)
emu.addMemoryCallback(function()
 if f>600 then local sl=emu.getState()['ppu.scanline'];assert(sl<0 or sl>=240,'Native VRAM upload must finish outside visible rendering') end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(0x19,stage);w(0x26,stage);w(0x24,0);w(0x1b,0);w(0x7005,1) end
 if f>600 and r(0x100)==1 and r(0x7001)==1 then live=live+1 end
 if f==900 then
  assert(r(0)==5 and r(0x19)==stage and r(0x1b)>=128 and live>250,'Stage '..stage..' mode '..r(0)..' stage '..r(0x19)..' state '..r(0x1b)..' live '..live..' player '..r(0x100))
  assert(splits>250,'Stage must preserve native status-bar timing')
  assert(updates>=298,'Stage opening must complete at native 60 fps')
  local out=assert(io.open(TEST_ROOT..'/build/stage-'..stage..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  print('PASS native stage '..(stage+1)..' intro, Mario and HUD');emu.stop(0)
 end
end,emu.eventType.endFrame)
