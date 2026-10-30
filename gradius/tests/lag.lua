-- Force the native busy-frame branch even on a quiet scene. It must repeat a
-- valid complete frame, restoring the stage CHR bank and the HUD at scanline 211.
local f=0
local held=0
local first=-1
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local rom=assert(io.open(TEST_ROOT..'/dist/Mario in Gradius.nes','rb')):read('*a')
emu.addEventCallback(function()setPad(0,{start=f>=200 and f<210,up=f>=400});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=600 and first~=f then
  first=f
  local bank=r(0x70c4)
  for i=0,8191 do
   assert(emu.read(i,emu.memType.nesPpuDebug)==rom:byte(0x8011+bank*8192+i),'Held frame must restore the exact displayed stage graphics')
  end
 end
end,emu.callbackType.exec,H.BusySplit)
emu.addMemoryCallback(function()
 if f>=600 then
  held=held+1
  local sl=emu.getState()['ppu.scanline']
  assert(sl>=210 and sl<=212,'Held frame must split the HUD on the native scanline: '..sl)
 end
end,emu.callbackType.exec,H.BusyHud)
emu.addMemoryCallback(function()
 if f>=600 then
  local sl=emu.getState()['ppu.scanline']
  assert(sl<0 or sl>=240,'Held frame must never upload VRAM during visible rendering')
 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==500 then w(0x7005,1) end
 if f==650 or f==700 then w(4,1) end
 if f==651 or f==701 then w(4,0) end
 if f==750 then
  assert(held==2,'Both forced busy frames must retain graphics and the HUD')
  assert(r(0)==5 and r(0x100)==1 and r(4)==0,'Normal play must resume after a busy frame')
  print('PASS forced busy frames retain complete CHR, scroll/HUD timing and VRAM safety');emu.stop(0)
 end
end,emu.eventType.endFrame)
