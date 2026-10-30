local f=0
local entered=nil
local draws=0
local shots=0
local steps=0
local own=0
local late=0
local paletteChecks=0
local attributeChecks=0
local pendingAttributes=nil
local needsAttributes=false
local fontFile=assert(io.open("C:/nes/Ghosts'n Goblins (USA).nes",'rb'));local nativeFont=fontFile:read('*a');fontFile:close()
local checkpoint=({0,3,7,9,11,12,13})[STAGE+1]
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,a=t>=80 and t%120<35,b=t>=40 and t%22<7,right=t>=150 and t<400});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()w(0xc2,checkpoint)end,emu.callbackType.exec,0xd0f7)
emu.addMemoryCallback(function()
 entered=entered or f;steps=steps+1
 w(0x4f0,(r(0x4f0)&0xde)|0x40);w(0x647,0)
 assert(r(0xcf)==STAGE,'native stage load reaches selected stage')
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 if entered then draws=draws+1;assert(r(H.M_ART_POSE)<26,'valid streamed Mario art')
  if r(H.M_ART_READY)==1 and r(H.M_ART_PHASE)==0 then
   local p=r(H.BodyTiles+r(H.M_ACTIVE))*16
   for i=0,127 do assert(emu.read(p+i,emu.memType.nesPpuDebug)==r(0x7000+r(H.M_ART_POSE)*128+i),'stage CHR reload retains complete Mario art')end
  end
 end
end,emu.callbackType.exec,H.DrawMario)
emu.addMemoryCallback(function()
 if not entered then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled'] then late=late+1 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function()
 if entered then needsAttributes=r(0x5a)==0 end
end,emu.callbackType.exec,H.NmiArt)
emu.addMemoryCallback(function()
 if not entered then return end
 local dst=r(0x56)+256*r(0x57);local src=r(0x58)+256*r(0x59)
 pendingAttributes={dst=dst,data={}}
 for i=0,31 do pendingAttributes.data[i]=r(src+i)end
end,emu.callbackType.exec,0xc1d3)
emu.addMemoryCallback(function()
 if not entered then return end
 if needsAttributes then assert(pendingAttributes,'Mario streaming must not starve native background attributes')end
 if pendingAttributes then
  for i=0,31 do assert(emu.read(pendingAttributes.dst+i,emu.memType.nesPpuDebug)==pendingAttributes.data[i],'native background attribute batch must reach hardware')end
  attributeChecks=attributeChecks+1;pendingAttributes=nil
 end
 needsAttributes=false
end,emu.callbackType.exec,0xc209)
emu.addMemoryCallback(function()
 if not entered then return end
 for tile=0,0x1d do
  if tile<16 or tile==0x1d then
   for i=0,15 do assert(emu.read(tile*16+i,emu.memType.nesPpuDebug)==nativeFont:byte(17+tile*16+i),'stage HUD glyph must remain native')end
  end
 end
 local page=(r(0x7d57)==1 and 0x7f or r(0xb1))*256
 for i=0,252,4 do
  local tile=r(page+i+1)
  local private=(tile>=0x22 and tile<0x2a)or(tile>=0x38 and tile<0x42)
  if r(page+i)<0xef and not private then
   local pal=r(page+i+2)&3
   for shade=1,3 do
    local actual=emu.read(0x3f10+pal*4+shade,emu.memType.nesPpuDebug)
    local native=r(H.M_NATIVE_PALS+pal*4+shade)&0x3f
    assert(actual==native,'visible native sprite palette changed: '..pal..':'..shade..' '..actual..' vs '..native..' frame '..f..' dma '..r(0xb1)..' sprite '..i..' tile '..r(page+i+1)..' selected '..r(H.M_PALETTE)..' old '..r(H.M_OLD_PALETTE)..' used '..r(0x7d4f))
    paletteChecks=paletteChecks+1
   end
  end
 end
end,emu.callbackType.exec,0xc20c)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2400,'stage enters');return end
 local t=f-entered
 if r(H.FB)>0 then own=own+1 end
 for x=17,19 do if r(0x4f0+x)~=0 then shots=shots+1 end end
 if t==340 then local o=assert(io.open(TEST_ROOT..'/build/stage-'..STAGE..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if t==500 then
  assert(steps>100 and draws>80 and own>20 and shots>20,'native stage, Mario and both attacks remain live')
  assert(late==0,'stage has no visible-rendering VRAM writes')
  assert(paletteChecks>100 and attributeChecks>30,'hardware enemy palettes and native background attributes are exercised')
  print('PASS native stage '..STAGE..' checkpoint '..checkpoint..', art, Mario control, independent and native shots; '..steps..' simulation steps');emu.stop(0)
 end
 assert(t<600,'stage fixture completes')
end,emu.eventType.endFrame)
