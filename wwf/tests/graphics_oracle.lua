-- Exact native raster phases and native CPU OAM, on every replay frame.
local nativeBody=nil;local dmaFrame=nil;WWF_RASTER_FRAMES=0
local file=assert(io.open(TEST_ROOT..'/build/native-background-reference.bin','rb'))
local background=file:read('*a');file:close()
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 local s=emu.getState()
 assert(s['ppu.scanline']==250 or s['ppu.scanline']==251,'CHR setup must rejoin the native late-vblank phase')
end,emu.callbackType.exec,0xA043)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 local s=emu.getState()
 assert(s['ppu.scanline']>=256 and s['ppu.scanline']<=257,'the first HUD reveal must occur at the native vblank phase')
end,emu.callbackType.exec,0xA08C)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0xABFF then return end
 local s=emu.getState()
 assert(s['ppu.scanline']>=0 and s['ppu.scanline']<=87,'drawing and HUD updates must finish before sprite-zero scanline 88; got '..s['ppu.scanline'])
end,emu.callbackType.exec,0xAD90)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0xABFF then return end
 local s=emu.getState()
 assert(s['ppu.scanline']==89,'HUD/ring blanking must start on scanline 89, got '..s['ppu.scanline'])
 dmaFrame=f;WWF_RASTER_FRAMES=WWF_RASTER_FRAMES+1
end,emu.callbackType.exec,0xADA3)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0xABFF then return end
 local s=emu.getState()
 assert(dmaFrame==f and s['ppu.scanline']>=103 and s['ppu.scanline']<=107,'ring display must resume in its native scanline window, got '..s['ppu.scanline'])
end,emu.callbackType.exec,0xADFE)
emu.addMemoryCallback(function()
 if r(0xc)~=4 then return end

 if mode()~=0xABFF or r(0xc)~=4 then return end
 if WWF_RASTER_FRAMES%120==0 then
  -- Native CC7D/CC9C generates participant-name glyphs through tile C1.
  -- Those depend on the entered name; C2 onward is the static HUD font.
  for i=32,1023 do if i<0x2f0 or i>=0x300 then
   assert(emu.read(0xc00+i,emu.memType.nesPpuDebug)==background:byte(i+1),'HUD/font CHR differs from original at '..string.format('%04X',0xc00+i))
  end end
  for i=0,3119 do assert(emu.read(0x1000+i,emu.memType.nesPpuDebug)==background:byte(1025+i),'ring and deformable rope CHR must match the original game')end
 end
 local front
 if r(0xd4)~=0 then front=1
 elseif r(0xd3)~=0 then front=0
 elseif r(0xcc)~=0 then front=1
 elseif r(0xcb)~=0 then front=0
 elseif r(0x2e)>r(0x2f)then front=0 else front=1 end
 nativeBody={}
 for actor=0,1 do
  if r(0x12d+actor)==255 then
   local base=actor==front and 0x700 or 0x758
   for i=0,79 do nativeBody[base+i]=r(base+i)end
   local dust=(r(0x2e)>=r(0x2f))==(actor==0)and 0x750 or 0x7a8
   for i=0,7 do nativeBody[dust+i]=r(dust+i)end
  end
 end
end,emu.callbackType.exec,H.Draw)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if not nativeBody then return end
 for a,v in pairs(nativeBody)do assert(r(a)==v,'Mario overlay must preserve original CPU body/shadow OAM at '..string.format('%04X',a))end
 nativeBody=nil
end,emu.callbackType.exec,0xAD6A)

-- Compare every displayed human body cell with the complete authored pose,
-- including side/melee art. Ropes share the pattern table with the bodies.
local streamFile=assert(io.open(TEST_ROOT..'/build/streamed-poses.chr','rb'))
local stream=streamFile:read('*a');streamFile:close()
WWF_BODY_FRAMES=0
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first or mode()~=0xABFF then return end
 for actor=0,1 do
  if r(0x12d+actor)~=255 and r(0x6104+actor)~=0 then
   local pose=r(0x4d8+actor);local group=r(0x4ea+actor)
   for cell=0,11 do
    local at=group+cell*4
    if emu.read(at,emu.memType.nesSpriteRam)<240 then
     local tile=emu.read(at+1,emu.memType.nesSpriteRam)
     for n=0,15 do
      assert(emu.read(0x1000+tile*16+n,emu.memType.nesPpuDebug)==stream:byte(pose*224+cell*16+n+1),
       'complete displayed body packet, frame '..(f-first)..' actor '..actor..' pose '..pose..' cell '..cell)
     end
    end
   end
   WWF_BODY_FRAMES=WWF_BODY_FRAMES+1
  end
 end
 for shot=0,3 do
  local at=0xf0+shot*4
  if emu.read(at,emu.memType.nesSpriteRam)<240 then
   local tile=emu.read(at+1,emu.memType.nesSpriteRam)
   local owner=shot//2;local phase=tile-r(0x6102+owner)
   assert(phase==12 or phase==13,'fireballs use their owner native packet spare cells')
   for n=0,15 do
    assert(emu.read(0x1000+tile*16+n,emu.memType.nesPpuDebug)==stream:byte(phase*16+n+1),'visible fireball CHR must be complete')
   end
  end
 end
end,emu.callbackType.exec,0xADFE)
