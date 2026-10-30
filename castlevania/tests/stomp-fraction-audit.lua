-- Capture the actual stomp handler's effect on fractional vertical motion.
-- Directed RAM fixtures; no controller-clear claim or ROM modification.
local frame=0;local seeded=false;local before=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function values()
 if AUDIT_SMB then return {r(0xce),r(0x9f),r(0x433),r(0x416)} end
 return {r(0x3f)-16,r(0x6005),r(0x6004),r(0x6006)}
end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 or seeded then return end
 seeded=true
 if AUDIT_SMB then
  w(0xe,8);w(0x772,3);w(0x747,0);w(0x716,0);w(0x723,0)
  w(0x754,0);w(0x756,1);w(0x86,80);w(0x6d,0);w(0xce,112);w(0xb5,1);w(0x1d,1)
  w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x73f,0)
  w(0x57,0);w(0x705,0);w(0x700,0);w(0x400,0);w(0x33,1);w(0x45,1)
  w(0x9f,2);w(0x433,112);w(0x416,128);w(0x714,0);w(0x709,112);w(0x70a,112)
  w(0x79e,0);w(0x79f,0);w(0x791,0)
  for a=0x500,0x69f do w(a,0) end
  for x=0,5 do w(0xf+x,0) end
  w(0xf,1);w(0x16,6);w(0x1e,0);w(0x87,80);w(0x6e,0);w(0xcf,132);w(0xb6,1)
  w(0x49a,9);w(0x491,0);w(0x3d8,0);w(0x58,0);w(0xa0,0);w(0x401,0)
 else
  local actor=19
  for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
  w(0x6001,1);w(0x600d,0);w(0x5b,0);w(0x45,64)
  w(0x3f,AUDIT_BEFORE[1]+16);w(0x354,r(0x3f));w(0x6008,r(0x3f)-2)
  w(0x6005,AUDIT_BEFORE[2]);w(0x6004,AUDIT_BEFORE[3]);w(0x6006,AUDIT_BEFORE[4]);w(0x46c,1)
  for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x60a0}) do w(base+actor,0) end
  w(0x434+actor,1);w(0x38c+actor,r(0x38c));w(0x354+actor,r(0x3f)+30);w(0x31c+actor,0x50)
 end
end,emu.callbackType.exec,AUDIT_ENTRY)
emu.addMemoryCallback(function() if seeded then before=values() end end,emu.callbackType.exec,AUDIT_STOMP_ENTRY)
emu.addMemoryCallback(function()
 if not before then return end
 local after=values()
 local f=assert(io.open(AUDIT_OUTPUT,'w'));f:write('phase,y,vy,vlo,yfrac\n')
 f:write('before,'..table.concat(before,',')..'\n');f:write('after,'..table.concat(after,',')..'\n');f:close()
 print('Actual stomp: '..table.concat(before,',')..' -> '..table.concat(after,','));emu.stop(0)
end,emu.callbackType.exec,AUDIT_STOMP_END)
emu.addEventCallback(function() frame=frame+1;assert(frame<750,'Stomp must occur in this directed fixture') end,emu.eventType.endFrame)
