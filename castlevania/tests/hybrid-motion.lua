local frame=0
local isSMB=false
local root=(TEST_ROOT..'/analysis/')
local log=assert(io.open(root..(isSMB and 'smb-motion.csv' or 'hybrid-motion.csv'),'w'))
log:write('frame,scenario,tick,x,y,state,xspeed,xforce,xabs,vhi,vlo,yfrac,gravity,fallforce,facing,moving,runflag,runtimer\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local scenario=0;local start=0
local seeds={0,16,25,28,0,0,24,0,0}
emu.addEventCallback(function()
 local t=frame-start
 local a=scenario>0 and scenario<=4 and t>=0 and t<25
 if scenario==5 then a=t==0 or (t>=6 and t<25) end
 if scenario==7 then a=t>=0 and t<25 end
 local right=(scenario==6 and t<55) or (scenario==8 and t<30) or (scenario==9 and t<100)
 local left=scenario==8 and t>=30 and t<70
 local b=(scenario==6 and t<55) or (scenario==7 and t>0 and t<25) or (scenario==9 and t>=50 and t<100)
 emu.setInput({start=frame==120,right=right,left=left,b=b,a=a},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame>=700 and (frame-700)%150==0 and frame<=1900 then
  scenario=math.floor((frame-700)/150)+1;start=frame
  local speed=seeds[scenario]
  if isSMB then
   w(0x723,0);w(0x0e,8);w(0x772,3);w(0x716,scenario>=6 and 1 or 0);w(0x71a,0);w(0x71b,0);w(0x71c,0);w(0x71d,255);w(0x73f,0);w(0x755,80);w(0x400,0);w(0x86,80);w(0x6d,0);w(0xce,176);w(0xb5,1);w(0x1d,0);w(0x57,speed);w(0x705,0);w(0x700,speed);w(0x703,0);w(0x783,0);w(0x33,1);w(0x45,1);w(0x9f,0);w(0x416,0);w(0x433,0);w(0x490,3);w(0xd,0);w(0x714,0)
  else
   w(0x38c,80);w(0x3a8,0);w(0x40,80);w(0x41,0);w(0x2e,0);w(0x2f,0);w(0x3f,176);w(0x354,176);w(0x46c,0);w(0x434,0);w(0x6001,0);w(0x6071,speed);w(0x6072,0);w(0x6073,speed);w(0x6074,0);w(0x6075,0);w(0x6076,1);w(0x6077,1);w(0x607f,0);w(0x6004,0);w(0x6005,0);w(0x6006,0);w(0x600d,90)
  end
 end
 if scenario>0 then
  if isSMB then
   for x=0,5 do w(0xf+x,0) end
   log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,scenario,frame-start,r(0x86)+256*r(0x6d),r(0xce),r(0x1d),r(0x57),r(0x705),r(0x700),r(0x9f),r(0x433),r(0x416),r(0x709),r(0x70a),r(0x33),r(0x45),r(0x703),r(0x783)))
  else
   for x=3,19 do if r(0x434+x)<0x28 then w(0x434+x,0) end end
   log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,scenario,frame-start,r(0x40)+256*r(0x41),r(0x3f),r(0x46c),r(0x6071),r(0x6072),r(0x6073),r(0x6005),r(0x6004),r(0x6006),r(0x6009),r(0x607d),r(0x6076),r(0x6077),r(0x6074),r(0x6075)))
  end
 end
 if frame==2030 then log:close();emu.stop(0) end
end,emu.eventType.endFrame)

if not isSMB then
 emu.addMemoryCallback(function()
  if scenario>0 then for x=3,23 do w(0x434+x,0);w(0x60a0+x,0) end end
 end,emu.callbackType.exec,0xcf19)
end
