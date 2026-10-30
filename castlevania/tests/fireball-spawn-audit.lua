-- Directed RAM-seeded actor-free shooting fixtures. Original ROMs unchanged.
local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local log=assert(io.open(AUDIT_OUTPUT,'w'))
log:write('case,tick,player_x,player_y,crouch,active,ball_x,ball_y,visible_x,visible_y\n')
local function seed(c)
 local facing=c%2==0 and 1 or 2
 if AUDIT_SMB then
  w(0xe,8);w(0x772,3);w(0x747,0);w(0x716,0);w(0x723,0)
  w(0x754,0);w(0x756,2);w(0x86,80);w(0x6d,0);w(0xce,160);w(0xb5,1);w(0x1d,0)
  w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x73f,0)
  w(0x57,0);w(0x705,0);w(0x700,0);w(0x400,0);w(0x33,facing);w(0x45,facing)
  w(0x9f,0);w(0x433,0);w(0x416,0);w(0x714,0);w(0xd,0);w(0x6fc,0)
  w(0x24,0);w(0x25,0);w(0x6ce,0)
  for a=0x500,0x69f do w(a,0) end
  for x=0,15 do w(0x5a0+x,0x61);w(0x670+x,0x61) end
 else
  w(0x28,0);w(0x600b,0);w(0x18,5);w(0x19,6)
  w(0x38c,88);w(0x40,88);w(0x41,0);w(0x2e,0);w(0x2f,0);w(0x2d,0);w(0x3a8,0)
  w(0x3f,176);w(0x354,176);w(0x46c,0);w(0x47,0);w(0x3c,4);w(0x142,0)
  w(0x6001,2);w(0x6070,0);w(0x6071,0);w(0x6072,0);w(0x6073,0);w(0x6074,0);w(0x6075,0)
  w(0x6076,facing);w(0x6077,facing);w(0x450,facing-1);w(0x607f,0);w(0x6013,0)
  w(0x6004,0);w(0x6005,0);w(0x6006,0);w(0x600d,90);w(0x45,64);w(0x44,64)
  w(0x6020,0);w(0x6021,0);w(0x603e,0);w(0x434,0);w(0x5b,0)
  for a=0x5a0,0x6ff do w(a,0) end
  for x=0,7 do w(0x630+x,0x55);w(0x6e0+x,0x55) end
 end
end
emu.addEventCallback(function()
 local c=math.floor((frame-700)/20)
 local t=(frame-700)%20
 emu.setInput({start=frame==120,down=c>=2 and c<4,b=c>=0 and c<4 and t==4},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 then return end
 if AUDIT_SMB then for x=0,5 do w(0xf+x,0) end
 else for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end end
end,emu.callbackType.exec,AUDIT_ENTRY)
emu.addEventCallback(function()
 frame=frame+1
 if frame>=700 and frame<780 and (frame-700)%20==0 then seed(math.floor((frame-700)/20)) end
 if frame>700 and frame<=780 then
  local c=math.floor((frame-701)/20)
  local t=(frame-701)%20+1
  local values
  if AUDIT_SMB then
   values={r(0x86),r(0xce),r(0x714),r(0x24),r(0x8d),r(0xd5),r(0x8d),r(0xd5)}
  else
   values={r(0x40)-8,r(0x3f)-16,r(0x6013),r(0x6020),r(0x6022),r(0x6024),r(0x6022)-4,r(0x6024)}
  end
  log:write(c..','..t..','..table.concat(values,',')..'\n')
 end
 if frame==780 then log:close();print('Captured standing/crouched fireball launches in both directions');emu.stop(0) end
end,emu.eventType.endFrame)
