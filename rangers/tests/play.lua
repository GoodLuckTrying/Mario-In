local f=0
local booted=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addMemoryCallback(function()
 local s=emu.getState();local x=s['cpu.x'];print('CONTACT '..f..' kind '..r(0x4e0+x)..' flags '..r(0x4d0+x)..' player '..s['cpu.y'])
end,emu.callbackType.exec,H.ContactGate)
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4,right=f>=650 and f<1150,b=f>=650 and f%14<7,a=(f>=740 and f<770) or (f>=910 and f<940)})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f%60==0 and f>=480 then
  print(string.format('F%d stage%d mode%d x%d.%d y%d.%d power%d carry%02X v%d,%d',f,r(0x31),r(0x54),r(0x500),r(0x4f0),r(0x520),r(0x510),r(0x6804),r(0x56),r(0x6806),r(0x6818)))
 end
 if f==700 or f==1000 then
  local q='palette ';for a=0x3f10,0x3f1f do q=q..string.format('%02X ',emu.read(a,emu.memType.nesPpuDebug)) end;print(q)
  q='buffer ';for a=0x310,0x31f do q=q..string.format('%02X ',r(a)) end;print(q)
  local o=io.open(TEST_ROOT..'/build/play-'..f..'.png','wb');o:write(emu.takeScreenshot());o:close()
 end
 if f==1200 then assert(r(0x500)>0 or r(0x4f0)>200,'Opening replay must move across the first screen');print('PASS opening replay');emu.stop(0) end
end,emu.eventType.endFrame)
