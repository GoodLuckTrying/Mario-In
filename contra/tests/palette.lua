local f=0
local stage=STAGE or 1
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180,up=f>=1000 and f<1010})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==480 then w(N.CURRENT_LEVEL,stage);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f==990 then w(N.INDOOR_SCREEN_CLEARED,1) end
 if f==950 or f==1250 then
  local lit=0
  for i=4,15 do if emu.read(0x3f00+i,emu.memType.nesPpuDebug)~=15 then lit=lit+1 end end
  assert(r(N.BG_PALETTE_ADJ_TIMER)==0 and lit>=8,'Base entrance and next room must finish their native fade and show visible background palettes')
 end
 if f%50==0 and f>=900 then
  local cpu,ppu={},{}
  for i=0,15 do cpu[#cpu+1]=r(N.PALETTE_CPU_BUFFER+i);ppu[#ppu+1]=emu.read(0x3f00+i,emu.memType.nesPpuDebug) end
  print(f..' timer '..r(N.BG_PALETTE_ADJ_TIMER)..' room '..r(N.LEVEL_SCREEN_SCROLL_OFFSET)..' count '..r(N.NUM_PALETTES_TO_LOAD)..' cpu '..table.concat(cpu,',')..' ppu '..table.concat(ppu,','))
 end
 if f==1400 then
  local o=assert(io.open(TEST_ROOT..'/build/palette-'..stage..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  print('PASS native base palettes stage '..stage)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
