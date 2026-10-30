local f=0
local booted=false
local swapped=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{start=not booted and f%90<4,right=COOP and not booted and f%30<4});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not swapped then swapped=true;emu.write(0x31,STAGE or 0,emu.memType.nesDebug) end
end,emu.callbackType.exec,0xc6b5)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then
  if not ORIGINAL then
   for i=0,7 do assert(emu.read(0x3f10+i,emu.memType.nesPpuDebug)==r(0x310+i),'Apple and enemy palettes must exactly match native colors') end
   assert(r(0x69e8)>=2,'Mario must use a separate hardware palette')
   if COOP then assert(r(0x69e9)>=2 and r(0x69e9)~=r(0x69e8),'Luigi must have his own palette') end
  end
  local a={};for i=0x310,0x31f do a[#a+1]=r(i) end;print('CPU palette '..table.concat(a,','))
  local a={};for i=0x3f10,0x3f1f do a[#a+1]=emu.read(i,emu.memType.nesPpuDebug) end;print('PPU palette '..table.concat(a,','))
  local a={};for i=0,252,4 do if r(0x200+i)<240 then a[#a+1]=string.format('%d:%02X/%02X',i,r(0x201+i),r(0x202+i)) end end;print(table.concat(a,' '))
  local o=assert(io.open(TEST_ROOT..'/build/palette-'..(ORIGINAL and 'original' or 'mario')..'.png','wb'));o:write(emu.takeScreenshot());o:close();print('PASS native enemy/apple palettes');emu.stop(0)
 end
end,emu.eventType.endFrame)
