-- Exercise the native fortress statue handler through Mario's hammer.
local f=0
local seeded=false
local tileAddress=nil
local released=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
dofile(TEST_ROOT..'/tests/reload_stage.lua')
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,select=f==770,b=f==790},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<750 or seeded or r(0xB6)~=8 then return end
 seeded=true
 for a=0x500,0x6DF do w(a,0) end
 for x=0,15 do w(0x5C0+x,0x50);w(0x6B0+x,0x50) end
 for a=0x761,0x7F1,8 do w(a,0) end
 w(0xFD,0);w(0x6804,1);w(0x723,128);w(0x720,184);w(0x721,0x80);w(0x680B,1)
 w(0x6805,0);w(0x6818,0);w(0x6819,0);w(0x682A,0);w(0x6835,0);w(0x6806,0);w(0x6807,0);w(0x6808,0)
 w(0x14F,3);w(0x3C,0);w(0x3E,0)
 local parity=r(0x1A)&1
 local base=r(0x7011+parity*2)+256*r(0x7012+parity*2)
 tileAddress=(base+182)&0xFFF0
 if parity==1 and (tileAddress>=0x700 or tileAddress%256>=224) then tileAddress=tileAddress-480 end
 tileAddress=tileAddress|9
 w(tileAddress,0x6A)
 released=r(0x156)
 print(string.format('Seed fortress statue at %04X, native room flag=%d bank=%d',tileAddress,r(0x37),r(0x6801)))
end,emu.callbackType.exec,0x8000)
emu.addEventCallback(function()
 f=f+1
 if f==600 then requestNativeStage(3) end
 if f==780 then assert(r(0x3C)==1,'Native fortress Select must equip Mario hammer once') end
 if f>=815 then
  assert(seeded,'Native fortress player update must run')
  print('Statue tile='..r(tileAddress)..' inventory='..r(0x14F)..' released='..r(0x156)..' prior='..released)
  assert(r(tileAddress)==0,'Hammer must break the native fortress statue metatile')
  assert(r(0x14F)==2,'Breaking a statue consumes one hammer')
  assert(r(0x156)==released+1,'Native Centurion release must be credited')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
