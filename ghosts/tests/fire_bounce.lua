local f=0;local entered=nil;local t=-1;local samples={};local completed=0;local maximum=0;local pending=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,b=t>=20 and t%60<2})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f
 -- Keep live native terrain/collisions, isolate this trajectory from enemies.
 for i=1,16 do w(0x4f0+i,0)end
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 for _,offset in ipairs({0,16})do
  local a=H.FB+offset;local age=r(a);local y=r(a+3);local v=r(a+6)
  local s=samples[offset]
  if age==0 then samples[offset]=nil
  elseif v==253 and (not s or s.velocity<128)then
   if s and s.start and s.n>=10 then
    local height=s.start-s.minimum
    assert(height>=12 and height<=18,'actual terrain bounce height '..height)
    assert(s.n<=26,'fireball must return promptly to native floor')
    completed=completed+1;maximum=math.max(maximum,height)
   end
   samples[offset]={start=y,minimum=y,n=0,velocity=v}
  elseif s then
   s.n=s.n+1;s.minimum=math.min(s.minimum,y);s.velocity=v
   if y==s.minimum and s.start-y>=12 and not pending then pending=true end
  end
 end
end,emu.callbackType.exec,H.FireUpdate)
emu.addEventCallback(function()
 f=f+1
 if pending==true then
  local o=assert(io.open(TEST_ROOT..'/build/fireball-short-bounce.png','wb'));o:write(emu.takeScreenshot());o:close();pending='saved'
 end
 if entered and f-entered>=700 then
  assert(completed>=4,'several native terrain bounces must complete, got '..completed)
  print('PASS actual native terrain: '..completed..' short fireball bounces, maximum apex '..maximum..' pixels');emu.stop(0)
 end
 assert(f<2500,'bounded bounce replay')
end,emu.eventType.endFrame)
