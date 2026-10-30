dofile(TEST_ROOT..'/tests/common.lua')
local stages={};local seen={};local started={};local before=nil;local frames=0;local current=nil
local samples={};local captures={}
function menuInput()
 local stage=(MODE or 0)==2 and r(0x6e)or(r(0x12b)==255 and 1 or 0)
 started[stage]=started[stage]or f
 current=stage;local t=f-started[stage];local p={};local q={};local pad=(MODE or 0)==2 and stage==1 and q or p
 if stage==0 and t>700 and r(0x18)&127==1 then pad.a=f%8==3
 else pad.down=t%100==10;pad.up=t%500==460 end
 return p,q
end
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0x87DB then return end
 local s=emu.getState();local line=s['ppu.scanline']
 assert(line>=250 and line<=254,'selection starts in the expected vblank; no work spills across frames: '..line)
 before=f
end,emu.callbackType.exec,0x8890)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0x87DB then return end
 local s=emu.getState();local line=s['ppu.scanline']
 assert(before==f,'the selection upload completes inside the same video frame')
 assert(line>=210 and line<=224,'selection graphics finish before the fixed bottom split: '..line)
 frames=frames+1;samples[#samples+1]=line
 seen[current]=seen[current]or{};seen[current][r(0x6d)]=true
end,emu.callbackType.exec,0x8959)
function tick(t)
 if mode()~=0x87DB or current==nil then return end
 local elapsed=f-started[current]
 if elapsed==300 and not captures[current]then screen('menu-raster-'..(MODE or 0)..'-'..current);captures[current]=true end
 if current==1 and elapsed>1000 then
  assert(seen[0][0]and seen[0][1],'both brothers and both carousel wrap directions were drawn')
  local choices=(MODE or 0)==2 and 2 or 6
  for i=0,choices-1 do assert(seen[1][i],'second menu retained expected identity '..i)end
  assert(frames>1600,'extended menu raster replay')
  finish('player/opponent selection raster timing, both wrap directions, stable frames, and all available choices')
 end
end
