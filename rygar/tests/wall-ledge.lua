-- Native stage-zero route, isolated from enemy damage. The first pit's wall
-- must not turn descending Mario into a stationary platform-supported actor.
local f=0;local began=nil;local wall=false;local stuck=0;local lastY=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=began and f-began or -1
 setPad(0,{start=not began and f>=120 and f%60<2,right=t>=20,b=t>=20,a=t>=70 and t<95})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
 if not began then
  if r(0x522)&0xA0==0 then return end
  began=f
 end
 local t=f-began;local y=r(0x4f2)
 if t>=240 and r(0x522)&0x88~=0 and y>165 then wall=true end
 if wall and r(H.M_STATE)~=0 and y==lastY then stuck=stuck+1 else stuck=0 end
 lastY=y
 assert(stuck<12,'falling beside the native ledge must not hang on a wall')
 if wall and y>=185 then
  print('PASS actual first-stage wall/ledge fall continues below y185');emu.stop(0)
 end
 assert(t<310,'native ledge route must exercise a continuing fall')
end,emu.callbackType.exec,0x9b9a)
emu.addEventCallback(function()f=f+1;assert(f<1500,'bounded native wall route')end,emu.eventType.endFrame)
