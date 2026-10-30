local karnov=TEST_ROOT:match('/karnov$')~=nil
local f=0;local started=nil;local previous={};local checks=0;local scrolled=0
local camera=karnov and 0x7d5e or 0x7d76
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=started and f-started or -1
 setPad(0,{start=not started and f>=120 and f%60<2,right=t>=30 and t<500,b=t>=30 and t<500 and t%45~=0})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if karnov and r(0x10)~=11 then return end
 started=started or f
 if karnov then for i=0,5 do w(0x650+i*16,0)end
 else for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end end
end,emu.callbackType.exec,karnov and 0xF28D or 0x9B9A)
emu.addEventCallback(function()
 f=f+1
 if started then
  for _,offset in ipairs({0,16})do
   local a=H.FB+offset;local age=r(a);local x=(r(a+1)+r(camera))&255;local old=previous[offset]
   if age~=0 and old and age==old.age+1 then
    local dir=r(a+6);local left=karnov and(dir&128)~=0 or not karnov and(dir&1)~=0
    local expected=left and 252 or 4
    assert((x-old.x)&255==expected,'fireball world speed must stay four pixels through native camera motion: '..((x-old.x)&255))
    checks=checks+1;if r(camera)~=old.camera then scrolled=scrolled+1 end
   end
   previous[offset]=age~=0 and {age=age,x=x,camera=r(camera)}or nil
  end
 end
 if started and f-started>=600 then
  assert(checks>=40 and scrolled>=20,'moving-camera shots exercised: '..checks..' / '..scrolled)
  print('PASS '..checks..' world-space fireball steps, '..scrolled..' during native camera movement');emu.stop(0)
 end
 assert(f<2000,'bounded moving-camera fire replay')
end,emu.eventType.endFrame)
