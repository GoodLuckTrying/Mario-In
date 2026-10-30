local f=0
local seeded=false
local power=POWER or 1
local tileAddress=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function tileAt(x,y)
 local parity=r(0x1A)&1
 local base=r(0x7BE0+parity*2)+256*r(0x7BE1+parity*2)
 local addr=(base+r(0xFD)+y)&0xFFF0
 if parity==1 and (math.floor(addr/256)>=7 or addr%256>=224) then addr=addr-480 end
 return addr|(x>>4)
end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,a=f>=600 and f<625},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=600 and not seeded then
  seeded=true
  w(0x6804,power);w(0x723,112);w(0x720,170);w(0x721,0x80);w(0x6805,1);w(0x6818,0xFC);w(0x6819,0);w(0x681A,0x20);w(0x681B,0x70);w(0x681C,170)
  w(0x6806,0);w(0x6807,0);w(0x6808,0);w(0x68A7,0);w(0x6830,0);w(0x68AD,0);w(0x6835,0)
  tileAddress=tileAt(116,146);w(tileAddress,0x59)
 end
end,emu.callbackType.exec,0xCBB6)
emu.addEventCallback(function()
 f=f+1
 if f==610 then
  assert(seeded,'Brick fixture must have executed')
  assert(r(0x6830)==0,'Ordinary masonry must never spawn a power-up')
  print('Brick pointer='..string.format('%04X',tileAddress)..' tile='..r(tileAddress)..' item='..r(0x6830)..' VY='..r(0x6818))
  if power>0 then
   assert(r(tileAddress)==0,'Big Mario must remove the native brick collision metatile')
   assert(r(0x68A0)==0,'NMI must consume the erase queue')
   local address=r(0x68A1)+256*r(0x68A2)
   for _,offset in ipairs({0,1,32,33}) do assert(emu.read(address+offset,emu.memType.nesPpuDebug)==0x12,'Broken brick background must be erased') end
   print('Brick shatter and PPU erase passed')
  else
   assert(r(tileAddress)==0x59,'Small Mario must retain the brick')
   print('Ordinary brick bump retains the brick and spawns no item')
  end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
