-- Validate the sprites actually sent to the PPU, including native hurt scripts.
local checkedFrames=0
local checkedSprites=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function p(a)return emu.read(a,emu.memType.nesPpuDebug)end
emu.addMemoryCallback(function()
 if r(H.M_MAGIC)~=0x4d or r(H.M_ART_READY)==0 or r(H.M_LIVE)==0 then return end
 local page=(r(0x7d57)==1 and 0x7f or r(0xb1))*256
 local seen={}
 for i=0,252,4 do
  local tile=r(page+i+1)
  local base=(tile>=0x22 and tile<0x2a)and 0x22 or((tile>=0x38 and tile<0x40)and 0x38 or nil)
  if base and r(page+i)<239 then
   local pose=seen[base]
   if not pose then
    for candidate=0,25 do
     local match=true
     for b=0,127 do if p(base*16+b)~=r(0x7000+candidate*128+b)then match=false;break end end
     if match then pose=candidate;break end
    end
    assert(pose,'displayed Mario buffer contains partial or overwritten CHR; base '..base)
    seen[base]=pose
   end
   local colors=(pose>=12 and pose<24)and {0x16,0x27,0x18}or {0x30,0x27,0x16}
   local pal=r(page+i+2)&3
   for shade=1,3 do assert(p(0x3f10+pal*4+shade)==colors[shade],'displayed Mario color changed; pose '..pose..' palette '..pal..' shade '..shade..' actual '..p(0x3f10+pal*4+shade)..' selected '..r(H.M_PALETTE)..' old '..r(H.M_OLD_PALETTE)..' pending '..r(0x7d52)..' live '..r(H.M_LIVE)..' native '..r(H.M_NATIVE)..' flags '..r(0x4f0)..':'..r(0x4f3))end
   checkedSprites=checkedSprites+1
  end
 end
 if next(seen)then checkedFrames=checkedFrames+1 end
end,emu.callbackType.exec,0xc20c)
function assertMarioGraphics()
 assert(checkedFrames>100 and checkedSprites>400,'displayed graphics oracle exercised')
 print('PASS actual displayed Mario CHR and all three hardware colors across '..checkedFrames..' frames / '..checkedSprites..' sprites')
end
