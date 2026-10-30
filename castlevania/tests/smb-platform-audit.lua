-- Native SMB horizontal platform, controlled placement and real A edge.
local frame=0;local seeded=false;local lastX=nil;local jumpSeen=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local log=assert(io.open(AUDIT_OUTPUT,'w'))
log:write('frame,x,xfrac,y,vy,platform_x,platform_fraction,platform_contact\n')
emu.addEventCallback(function()
 emu.setInput({start=frame==120,a=frame>=720 and frame<727},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 then return end
 for x=1,5 do w(0xf+x,0) end
 if not seeded then
  seeded=true
  w(0xe,8);w(0x772,3);w(0x747,0);w(0x716,0);w(0x723,0)
  w(0x754,0);w(0x756,1);w(0x86,80);w(0x6d,0);w(0xce,112);w(0xb5,1);w(0x1d,0)
  w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x73f,0)
  w(0x57,0);w(0x705,0);w(0x700,0);w(0x400,0);w(0x33,1);w(0x45,1)
  w(0x9f,0);w(0x433,0);w(0x416,0);w(0x714,0);w(0xd,0);w(0x6fc,0)
  w(0xf,1);w(0x16,0x28);w(0x1e,0);w(0x87,64);w(0x6e,0);w(0xcf,144);w(0xb6,1)
  w(0x49a,6);w(0x3a2,255);w(0x58,14);w(0xa0,2);w(0x401,0)
  for a=0x500,0x69f do w(a,0) end
  w(0xa,0);w(0xb,0);w(0xc,0)
 end
end,emu.callbackType.exec,AUDIT_ENTRY)
emu.addEventCallback(function()
 frame=frame+1
 if seeded then
  local x=r(0x86)+256*r(0x6d)
  log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d\n',frame,x,r(0x400),r(0xce),r(0x9f),r(0x87),r(0x401),r(0x3a2)))
  if not jumpSeen and r(0x9f)>=128 then
   assert(lastX and x==lastX,'SMB takeoff with zero own speed must not retain horizontal platform carry')
   assert(r(0x3a2)==255,'SMB clears platform collision on the takeoff frame')
   print('SMB takeoff: zero own X displacement; platform contact cleared on first rising frame')
   jumpSeen=true
  end
  lastX=x
 end
 if frame==729 then assert(jumpSeen,'Must take off from the native platform');log:close();emu.stop(0) end
end,emu.eventType.endFrame)
