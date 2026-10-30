-- Check the actual displayed native sprite patterns, not just CPU routines.
local file=assert(io.open('C:/nes/Snake Rattle n Roll (USA).nes','rb'))
local original=file:read('*a');file:close()
local native={}
local writers={}
local kinds={}
GRAPHICS_CHECKS=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addMemoryCallback(function(address,value)
 if address%4~=1 then return end
 local pc=emu.getState()['cpu.pc']
 native[(address-0x201)//4]=pc>=0x8000 and value or nil
 writers[(address-0x201)//4]=pc
 kinds[(address-0x201)//4]=r(0x49b+r(0x86))
end,emu.callbackType.write,0x201,0x2FD)
emu.addMemoryCallback(function()
 if r(0x7094)~=1 then return end
 local source=r(0xe2)
 if source~=1 and source~=4 and source~=5 then return end
 local pattern=(r(0)&8)~=0 and 0x1000 or 0
 for cell,tile in pairs(native)do
  if r(0x200+cell*4)<240 then
   for n=0,15 do
    local expected=original:byte(0x8010+source*4096+tile*16+n+1)
    local actual=emu.read(pattern+tile*16+n,emu.memType.nesPpuDebug)
    assert(actual==expected,string.format('native sprite CHR mismatch source %d tile %02X byte %d cell%d writer%04X kind%02X scene%02X%02X atlas%d',source,tile,n,cell,writers[cell],kinds[cell],r(0x11),r(0x10),r(0x7093)))
   end
   GRAPHICS_CHECKS=GRAPHICS_CHECKS+1
  end
 end
-- Check after native music reads and DisplayBank restore the visible CHR
-- selection. At FF9C an intermission may still be using its font bank;
-- E2 describes gameplay sprites, not those native menu glyphs.
end,emu.callbackType.exec,0x8CCF)
