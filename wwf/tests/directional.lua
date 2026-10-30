MODE=2
dofile(TEST_ROOT..'/tests/common.lua')
local source=dofile(TEST_ROOT..'/build/directional-fixtures.lua')
local drawn=nil
local seen={{},{}}
local frames=0
local dma=nil
local dirs={{down=true},{right=true,down=true},{right=true,up=true},{up=true},{left=true,up=true},{left=true,down=true}}
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if r(0xc)~=0 then return end
 if first then w(0x79,200);w(0x7a,200)end
end,emu.callbackType.exec,H.UpdateBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if first then
  drawn={}
  for p=0,1 do drawn[p]={pose=r(0x4d8+p),map=r(0x4ed+p),attr=r(0x4f3+p),x=r(0x4ef+p),y=r(0x4f1+p),group=r(0x4ea+p)}end
 end
end,emu.callbackType.exec,0xAD6A)
emu.addMemoryCallback(function(a,value)
 if value~=7 or not drawn then return end
 dma={}
 for p=0,1 do
  local d=drawn[p];local pose=d.pose
  if r(0x12d+p)~=255 and pose>=11 then
   seen[p+1][pose]=true
   local ref=source[pose+1]
   for cell=0,11 do
    local base=0x700+d.group+cell*4
    local sy,tile,attr,sx=r(base),r(base+1),r(base+2),r(base+3)
    local wanted=false
    for y=0,7 do for x=0,7 do if ref[(cell//3)*8+y+1]:sub((cell%3)*8+x+1,(cell%3)*8+x+1)~='0'then wanted=true end end end
    if sy<240 then
     for y=0,7 do
      local lo=emu.read(0x1000+tile*16+y,emu.memType.nesPpuDebug)
      local hi=emu.read(0x1000+tile*16+8+y,emu.memType.nesPpuDebug)
      for x=0,7 do
       local bit=(attr&64)~=0 and x or 7-x
       local pixel=((lo>>bit)&1)|(((hi>>bit)&1)<<1)
       local rx=(cell%3)*8+((attr&64)~=0 and 7-x or x)
       assert(pixel==tonumber(ref[(cell//3)*8+y+1]:sub(rx+1,rx+1)),'hardware directional pixels, player '..p..' pose '..pose..' cell '..cell)
      end
     end
    elseif wanted and d.y+(cell//3)*8>=0x66 and d.y+(cell//3)*8<0xef and r(0x76)==0 then error('a nonempty directional body cell disappeared')end
    for i=0,3 do dma[d.group+cell*4+i]=r(base+i)end
   end
   frames=frames+1
  end
 end
 drawn=nil
end,emu.callbackType.write,0x4014)
function input(t)return dirs[(t//36)%#dirs+1]end
function input2(t)return dirs[(t//36+3)%#dirs+1]end
function tick(t)
 if dma then
  for offset,value in pairs(dma)do assert(emu.read(offset,emu.memType.nesSpriteRam)==value,'directional art must reach hardware OAM')end
  dma=nil
 end
 if t==140 then screen('directional-gameplay')end
 if t==1200 then
  for p=1,2 do
   assert(seen[p][11]or seen[p][12]or seen[p][13],'front views must animate for both brothers')
   assert(seen[p][14]or seen[p][15]or seen[p][16],'back views must animate for both brothers')
   assert(seen[p][17]or seen[p][18],'front-diagonal views must reach both players')
   assert(seen[p][19]or seen[p][20],'back-diagonal views must reach both players')
  end
  assert(frames>500,'exercise sustained directional streaming; got '..frames)
  finish('supplied front/back/diagonal pixels, both players, native CHR pipeline, hardware OAM and exact native raster phases')
 end
end
