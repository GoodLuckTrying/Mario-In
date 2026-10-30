-- RAM fixtures compare actual engine updates; this is not a controller clear.
local frame=0
local number=0
local tick=0
local seeded=false
local output=assert(io.open(PHYSICS_OUTPUT,'w'))
output:write('case,tick,x,xfrac,y,yfrac,state,xspeed,xforce,xabs,vhi,vlo,gravity,fallforce,facing,moving,runflag,runtimer,crouch\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function terrain(case)
 if PHYSICS_SMB then
  for a=0x500,0x69f do w(a,0) end
  for page=0,1 do for x=0,15 do
   local world=page*256+x*16
   local y=case.kind=='ledge' and world>=112 and world<208 and 208 or 192
   w((page==0 and 0x500 or 0x5d0)+y-32+x,0x61)
   if case.roof then w((page==0 and 0x500 or 0x5d0)+case.roof-32+x,0x61) end
  end end
 else
  for a=0x5a0,0x6ff do w(a,0) end
  local parity=r(0xfbd6)
  for page=0,1 do for x=0,255,8 do
   local world=page*256+x
   local y=case.kind=='ledge' and world>=112 and world<208 and 208 or 192
   local base=(page+parity)%2==0 and 0x5a0 or 0x650
   local address=base+y-48+math.floor(x/32)
   w(address,r(address)+2^((3-math.floor(x/8)%4)*2))
   if case.roof then
    for y=case.roof,case.roof+8,8 do
     local address=base+y-48+math.floor(x/32)
     w(address,r(address)+2^((3-math.floor(x/8)%4)*2))
    end
   end
  end end
 end
end
local function seed(case)
 local speed=case.speed
 local direction=speed<0 and 2 or 1
 local x=case.origin or (case.kind=='ledge' and speed<0 and 224 or 80)
 if PHYSICS_SMB then
  w(0x723,0);w(0x0e,8);w(0x772,3);w(0x716,0);w(0x747,0);w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x73f,0)
  -- Every case gets a fresh level timer; a long fixture batch must not
  -- enter SMB's time-up death dispatcher between movement samples.
  w(0x7f8,4);w(0x7f9,0);w(0x7fa,0);w(0x759,0);w(0x787,24)
  w(0x755,x);w(0x754,case.power==0 and 1 or 0);w(0x756,case.power)
  w(0x400,case.fraction or 0);w(0x86,x%256);w(0x6d,math.floor(x/256));w(0xce,160);w(0xb5,1);w(0x1d,0)
  w(0x57,speed);w(0x705,0);w(0x700,math.abs(speed));w(0x703,0);w(0x783,0);w(0x33,direction);w(0x45,direction)
  w(0x9f,0);w(0x416,0);w(0x433,0);w(0x709,32);w(0x70a,112);w(0x490,255);w(0xd,0);w(0x714,0);w(0x706,1)
 else
  w(0x28,0);w(0x38c,case.origin and case.direction<0 and 128 or x+8);w(0x3a8,case.fraction or 0);w(0x40,(x+8)%256);w(0x41,math.floor((x+8)/256));w(0x2e,case.origin and case.direction<0 and x-120 or 0);w(0x2f,0);w(0x2d,case.fraction or 0)
  w(0x3f,176);w(0x354,176);w(0x46c,0);w(0x434,0);w(0x47,0);w(0x6001,case.power);w(0x6070,0);w(0x3c,4);w(0x142,0)
  w(0x6071,speed);w(0x6072,0);w(0x6073,math.abs(speed));w(0x6074,0);w(0x6075,0);w(0x6076,direction);w(0x6077,direction);w(0x607f,0)
  w(0x6004,0);w(0x6005,0);w(0x6006,0);w(0x6009,32);w(0x607d,112);w(0x600d,90);w(0x5b,0);w(0x45,64);w(0x44,64)
  w(0x603e,0);w(0x6020,0);w(0x6021,0);w(0x6013,0);w(0x6063,3)
 end
 terrain(case)
end
local function input(case,t)
 local moving=(case.direction or (case.speed>=0 and 1 or -1))>0 and 'right' or 'left'
 local opposite=moving=='right' and 'left' or 'right'
 local joy={a=false,b=false,left=false,right=false,up=false,down=false,start=false,select=false}
 if case.kind=='start-run' or case.kind=='start-walk' then joy[moving]=t<64;joy.b=case.kind=='start-run' and t<64
 elseif case.kind=='release-run' then joy[moving]=t<64;joy.b=t<16
 elseif case.kind=='neutral-brake' then joy[moving]=t>=48 and t<64
 elseif case.kind=='simultaneous' then joy.left=t<48;joy.right=t<48;joy.b=t<16;joy.a=t>=8 and t<32
 elseif case.kind=='air-neutral' then joy.a=t<25;joy[moving]=t>=36 and t<48
 elseif case.kind=='repress-jump' then joy.a=t<3 or (t>=6 and t<25);joy[moving]=t<48
 elseif case.kind=='down-direction' then joy.down=t<24;joy[moving]=t<48;joy.a=t>=8 and t<32
 elseif case.kind=='up-down' then joy.up=t<24;joy.down=t<24;joy.a=t>=8 and t<32
 elseif case.kind=='crouch-ceiling' then joy.down=t<32;joy.a=t>=8 and t<32
 elseif case.kind=='duck-slide' then joy.down=t<60
 elseif case.kind=='duck-jump' then joy.down=t<16;joy.a=t>=8 and t<28
 elseif case.kind=='duck-release' then joy.down=t<12;joy[moving]=t>=12 and t<32
 elseif case.kind=='jump' then joy.a=t<case.held
 elseif case.kind=='air-turn' then joy.a=t<25;joy[t<20 and moving or opposite]=t<45
 elseif case.kind=='re-jump' then joy[moving]=t<20;joy.a=t<65 or t>=68
 elseif case.kind=='ledge' then joy[moving]=t<60
 else joy[t<32 and moving or opposite]=t<64;joy.b=case.kind=='run-reverse' and t<64 end
 return joy
end
emu.addEventCallback(function()
 local joy={start=frame==120}
 if number>0 then joy=input(PHYSICS_CASES[number],tick) end
 emu.setInput(joy,0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 then return end
 if number==0 then number=1;seeded=false end
 if not seeded then seed(PHYSICS_CASES[number]);tick=0;seeded=true end
 terrain(PHYSICS_CASES[number])
 if PHYSICS_SMB then for x=0,5 do w(0xf+x,0) end
 else for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end end
 -- The first fixture input was polled before initialization: set the same
 -- controller registers on both engines for that one setup update.
 if tick==0 then
  local joy=input(PHYSICS_CASES[number],0)
  local bits=(joy.a and 128 or 0)+(joy.b and 64 or 0)+(joy.left and 2 or 0)+(joy.right and 1 or 0)+(joy.down and 4 or 0)+(joy.up and 8 or 0)
  if PHYSICS_SMB then
   local filtered=joy.down and (joy.left or joy.right)
   w(0xa,bits&192);w(0xb,filtered and 0 or bits&12);w(0xc,filtered and 0 or bits&3);w(0x6fc,bits)
  else w(0xf7,bits);w(0xf5,bits) end
 end
end,emu.callbackType.exec,PHYSICS_ENTRY)
emu.addMemoryCallback(function()
 if not seeded or frame<700 then return end
 tick=tick+1
 local values
 if PHYSICS_SMB then
  values={r(0x86)+256*r(0x6d),r(0x400),r(0xce),r(0x416),r(0x1d),r(0x57),r(0x705),r(0x700),r(0x9f),r(0x433),r(0x709),r(0x70a),r(0x33),r(0x45),r(0x703),r(0x783),r(0x714)}
 else
  values={r(0x40)+256*r(0x41)-8,r(0x3a8),r(0x3f)-16,r(0x6006),r(0x6070),r(0x6071),r(0x6072),r(0x6073),r(0x6005),r(0x6004),r(0x6009),r(0x607d),r(0x6076),r(0x6077),r(0x6074),r(0x6075),r(0x6013)}
 end
 output:write(number..','..tick..','..table.concat(values,',')..'\n')
 if tick==80 then
  number=number+1;seeded=false
  if number>#PHYSICS_CASES then output:close();print('Captured '..#PHYSICS_CASES..' matched physics fixtures');emu.stop(0) end
 end
end,emu.callbackType.exec,PHYSICS_END)
emu.addEventCallback(function() frame=frame+1;if frame==700+100*#PHYSICS_CASES then assert(false,'Physics fixtures timeout') end end,emu.eventType.endFrame)
