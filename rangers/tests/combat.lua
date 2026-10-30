local f=0
local p=PLAYER or 0
local power=POWER or 0
local mode=MODE or 'stomp'
local base=0x6800+p*128
local booted=false
local armed=false
local hits=0
local attempts=0
local checked=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not armed then return end
 local x=emu.getState()['cpu.x']
 if x~=14 and x~=15 then return end
 attempts=attempts+1
 -- Preserve native enemy update/dispatch; control only the contact geometry.
 w(0x4f0+x,100+(x==14 and 8 or 0));w(0x500+x,0);w(0x510+x,160);w(0x520+x,5)
 w(0x400+x,0xD0);w(0x570+x,0)
 w(0x4f0+p,100);w(0x500+p,0);w(0x520+p,5);w(0x400+p,0xD0)
 if mode=='stomp' or mode=='hazard' then
  w(0x510+p,142)
  w(base+5,2);w(base+0x18,2);w(base+0x2f,134);w(base+0x4f,5)
 elseif mode=='overhead' then
  w(0x510+p,180);w(base+5,0);w(base+0x18,0)
 else
  w(0x510+p,160);w(base+5,1);w(base+0x18,0xFD)
 end
end,emu.callbackType.exec,H.CollisionGate)
emu.addMemoryCallback(function()
 if not armed then return end
 local x=emu.getState()['cpu.x']
 if x==14 or x==15 then hits=hits+1 end
end,emu.callbackType.exec,H.ContactGate)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then
  w(0x50,1);w(0x98,0)
  for q=0,1 do
   w(0x4d0+q,q==p and 0x80 or 0);w(0x54+q,0);w(0x5e+q,0);w(0x6800+q*128,0x4D);w(0x684c+q*128,2);w(0x69c4+q,0)
  end
  w(base+4,power);w(base+0x35,0);w(base+0x49,0)
  for s=2,15 do w(0x4d0+s,0) end
  for s=PAIR and 14 or 15,15 do
   for a=0x400+s,0x580+s,16 do w(a,0) end
   w(0x4d0+s,0xC1);w(0x4e0+s,HAZARD_KIND or 2);w(0x420+s,HAZARD_KIND and 0x66 or 0x1C);w(0x490+s,120)
  end
  armed=true
 end
 if f>=704 and not checked and(f>=724 or hits>0 or(mode=='overhead'and power==0 and attempts>=2))then
  checked=true
  armed=false
  print('hits '..hits..' actor '..r(0x4ef)..' player '..r(0x54+p)..' power '..r(base+4))
  if mode=='hazard' then
   assert(hits>0 and r(0x4ef)==HAZARD_KIND,'Landing on an electric Sparky must not defeat or convert it')
   if power>0 then
    assert(r(base+4)==0 and r(0x54+p)<6 and r(0x5e+p)>0,'Sparky contact must shrink tall forms and grant native damage invulnerability')
   else
    assert(r(0x54+p)==10,'Landing on a Sparky must kill small form')
   end
   assert(r(base+0x18)<128,'A Sparky must never give the enemy-stomp bounce')
  elseif mode=='stomp' then
   assert(hits>0 and r(0x4ef)==0x1C,'Landing must defeat the native enemy')
   assert(r(base+4)==power and r(base+0x18)>=128,'Stomp bounces without shrinking')
   if PAIR then assert(r(0x4ee)==0x1C,'Adjacent enemy must share the same stomp') end
  elseif mode=='overhead' and power==0 then
   assert(hits==0 and r(base+4)==0,'Overhead enemy misses the small body')
  elseif power>0 then
   assert(hits>0 and r(base+4)==0 and r(0x54+p)<6,'Enemy contact shrinks tall forms')
  else
   assert(hits>0 and r(0x54+p)==10,'Small form dies on side contact')
  end
 end
 if f==760 and not RETRY then print('PASS combat '..mode..' player '..p..' form '..power..' hazard '..tostring(HAZARD_KIND));emu.stop(0) end
 if f==1150 and RETRY then
  print('retry state '..r(0x54+p)..' magic '..r(base)..' power '..r(base+4)..' supplies '..r(base+0x4c)..' stage '..r(0x31)..' active '..r(0x4d0+p)..' lives '..r(0x5aa)..','..r(0x5da))
  assert(r(0x54+p)<6 and r(base+4)==0 and r(0x69c4)==0 and r(0x69c5)==0,'Death retries as small form without free supplies')
  print('PASS small death retry player '..p);emu.stop(0)
 end
end,emu.eventType.endFrame)
