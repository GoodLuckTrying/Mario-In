local f=0
local booted=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then w(0x6c,ROOM or 1) end
 if f==950 then
  local o=io.open(TEST_ROOT..'/build/room-'..(ROOM or 1)..'.png','wb');o:write(emu.takeScreenshot());o:close()
  print('camera '..r(0xfd)..','..r(0xfb)..' at '..r(0xfc)..','..r(0xfa)..' room '..r(0x6e))
  for i=0,15 do if r(0x4d0+i)>=128 then print(i..' kind '..r(0x4e0+i)..' flags '..r(0x570+i)..' pos '..r(0x4f0+i)..','..r(0x510+i)..' hp '..r(0x490+i)..','..r(0x4a0+i)) end end
  assert(r(0x6982)==1 and r(0x4d0)>=128,'Native transition returns to live Mario gameplay')
  if ROOM==2 then assert(r(0xfd)==6 and r(0xfb)==2,'Native bonus-room camera/header')
  else assert(r(0xfd)==0 and r(0xfb)==0,'Native interior camera/header') end
  for i=0,3 do assert(r(0x69a0+i)==0,'Room transitions clear custom fireballs') end
  print('PASS room transition');emu.stop(0)
 end
end,emu.eventType.endFrame)
