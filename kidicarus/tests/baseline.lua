local f=0
local root=(TEST_ROOT..'/build/')
local log=assert(io.open(root..'baseline.csv','w'))
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function footTile(x,y)
 local parity=r(0x1A)&1
 local base=r(0x7BE0+parity*2)+256*r(0x7BE1+parity*2)
 local addr=(base+r(0xFD)+y)&0xFFF0
 if parity==1 and (math.floor(addr/256)>=7 or addr%256>=224) then addr=addr-480 end
 return r(addr|(x>>4))
end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,right=f>500 and f<560,a=f>570 and f<605,b=false},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f>=300 and r(0xA0)==2 and r(0x6805)==0 and r(0x4D3)~=255 and r(0x720)<228 then
  local x=r(0x723);local feet=(r(0x720)+8)%256
  if footTile((x-1)%256,feet)>=0x50 or footTile((x+8)%256,feet)>=0x50 then
   assert((feet+r(0xFD))%16==0,'Controller replay: Mario must stand on the surface, never inside masonry')
  end
 end
 if f%5==0 then log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',f,r(0xa0),r(0x12f),r(0x720),r(0x723),r(0x1c),r(0x1d),r(0x1e),r(0x16),r(0x18),r(0xa5))) end
 if f==500 or f==560 or f==600 or f==700 then
  local o=assert(io.open(root..'baseline-'..f..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  local o=assert(io.open(root..'baseline-'..f..'.ram','wb'));for a=0,0x7ff do o:write(string.char(r(a))) end;o:close()
  local o=assert(io.open(root..'baseline-'..f..'.chr','wb'));for a=0,0x1fff do o:write(string.char(emu.read(a,emu.memType.nesPpuDebug))) end;o:close()
  local o=assert(io.open(root..'baseline-'..f..'.wram','wb'));for a=0x6000,0x7fff do o:write(string.char(r(a))) end;o:close()
  local o=assert(io.open(root..'baseline-'..f..'.state.txt','w'));for k,v in pairs(emu.getState()) do o:write(tostring(k)..'='..tostring(v)..'\n') end;o:close()
  if f==500 then
   for k,v in pairs(emu.memType) do if string.find(string.lower(k),'sprite') then print('memory '..k..'='..v) end end
   local o=assert(io.open(root..'actual-oam.bin','wb'));for a=0,255 do o:write(string.char(emu.read(a,emu.memType.nesSpriteRam))) end;o:close()
  end
 end
 if f>=720 then log:close();emu.stop(0) end
end,emu.eventType.endFrame)
