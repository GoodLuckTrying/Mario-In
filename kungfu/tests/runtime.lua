local f=0
local stage=STAGE or 0
local logic=0
local dma=0
local late=0
local badPpu=0
local groundX=nil
local minimum=135
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addMemoryCallback(function()if f>700 then logic=logic+1 end end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>700 then
  dma=dma+1
  local s=emu.getState()
  if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then late=late+1 end
 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 local controls={start=f>=180 and f<190}
 if f>=710 and f<780 then controls.right=true end
 if f>=850 and f<870 then controls.up=true end
 if f>=960 and f<1100 then controls.b=f%12<2;controls.a=f%24>=12 and f%24<14 end
 setPad(0,controls)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==700 then
  assert(r(0x5f)==stage,'native floor selection')
  assert(r(0x7c00)==0,'life must start small')
 end
 if f>=700 and f<=950 then
  for i=0,5 do w(0x80+i,0)end
  w(0x373,0);w(0x374,0)
 end
 if f==820 then groundX=r(0xd4)+r(0xe5)*256 end
 if f==845 then assert(r(0xd4)+r(0xe5)*256==groundX,'release must stop sliding')end
 if f>=850 and f<940 then minimum=math.min(minimum,r(0xb6))end
 if f==940 then
  assert(minimum<110,'jump must rise')
  assert(r(0xb6)==135,'land at original floor')
  w(0x3b1,4)
 end
 if f==950 then assert(r(0x7c00)==1,'four defeats grant mushroom');w(0x3b1,8)end
 if f==960 then assert(r(0x7c00)==2,'eight defeats grant flower')end
 if f==990 then
  local out=assert(io.open(TEST_ROOT..'/build/floor-'..stage..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==1100 then
  assert(dma>=380,'frame DMA must remain live')
  assert(late==0,'DMA must stay in vblank: '..late)
  assert(logic>=370,'player updates must keep frame rate: '..logic)
  print('PASS floor '..stage..' boot, Mario, movement, jump, growth, fire, timing; updates '..logic..' DMA '..dma)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
