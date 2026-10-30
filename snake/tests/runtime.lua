local f=0
local stage=STAGE or 0
local players=PLAYERS or 2
local selected=false
local dma=0
local late=0
local rendered={false,false}
local maxZ=0
local calls=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 if not selected then w(0xaa,(stage-1)&255);selected=true end
end,emu.callbackType.exec,0x82BF)
emu.addMemoryCallback(function()
 if f>800 then calls=calls+1 end
end,emu.callbackType.exec,H.SceneGate)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if f>800 then
  dma=dma+1
  if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then late=late+1 end
 end
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 local y=emu.getState()['cpu.y']
 if f>800 and y<2 then rendered[y+1]=true end
end,emu.callbackType.exec,H.DrawMario)
emu.addEventCallback(function()
 local start=f>=700 and f<710
 local a=f>=1010 and f<1030
 local b=f>=920 and f<1010 and f%14<2
 setPad(0,{start=start,a=a,b=b})
 setPad(1,{a=a,b=b})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,players==2 and 1 or 0)end
 if f==800 then
  assert(selected and r(0xaa)==stage,'native level selection')
  assert(r(0x49b)==1,'Mario active')
  if players==2 then assert(r(0x49c)==2,'Luigi active')end
 end
 -- Form fixtures exercise rendering; controller meals are tested separately.
 if stage==0 then
  if f==820 then
   for p=0,players-1 do w(0x59f+p,1+p*64);w(0x7002+p,1);w(0x7004+p,0);w(0x7000+p,0)end
  end
  if f==850 then for p=0,players-1 do w(0x7000+p,1)end end
  if f==890 then for p=0,players-1 do w(0x7000+p,2)end end
  if f>=1010 and f<1070 then maxZ=math.max(maxZ,r(0x527))end
 end
 if f==990 then
  local out=assert(io.open(TEST_ROOT..'/build/level-'..stage..'-p'..players..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==1120 then
  assert(rendered[1],'Mario must render')
  if players==2 then assert(rendered[2],'Luigi must render')end
  assert(dma>=280,'DMA must remain active throughout the 320-frame window '..dma)
  assert(late==0,'DMA outside vblank '..late)
  assert(calls>=100,'native playfield updates must continue '..calls)
  if stage==0 then assert(maxZ>35,'Mario jump must rise '..maxZ)end
  print('PASS stage '..stage..' P'..players..' boot, characters, frame timing; calls '..calls..' DMA '..dma)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
