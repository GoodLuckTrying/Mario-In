local f=0
local banks={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function save(t)
 local prefix=TEST_ROOT..'/build/'..(CAPTURE_PREFIX or 'native')..'-'..t
 local o=assert(io.open(prefix..'.png','wb'));o:write(emu.takeScreenshot());o:close()
 o=assert(io.open(prefix..'.ram','wb'));for a=0,0x7ff do o:write(string.char(r(a)))end;o:close()
 o=assert(io.open(prefix..'.ppu','wb'));for a=0,0x3fff do o:write(string.char(emu.read(a,emu.memType.nesPpuDebug)))end;o:close()
 print('CAP '..f..' game '..r(0x1d)..' engine '..r(0x1c)..' mode '..r(4)..' Mac '..r(0x50)..' pose '..r(0x61)..' chr '..r(0x69)..' fight '..r(2)..':'..r(3)..' hp '..r(0x392)..' opp '..r(0x399))
end
emu.addEventCallback(function()
 setPad(0,{start=f<1600 and f%180<3,a=f>=1700 and f%40<6,b=f>=1700 and f%40>=20 and f%40<26,up=f>=1700 and f%160<80,left=f>=2000 and f%240<12,down=f>=2200 and f%240>=120 and f%240<126});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(a,v)
 banks[a]=v
end,emu.callbackType.write,0xb000,0xefff)
emu.addEventCallback(function()
 f=f+1
 if f==300 or f==600 or f==1000 or f==1600 or f==1900 or f==2200 or f==2500 then save(f)end
 if f==2700 then print('PASS native fight capture');emu.stop(0)end
end,emu.eventType.endFrame)
