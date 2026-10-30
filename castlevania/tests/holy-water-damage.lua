-- Controlled native pickup/throw/landing/damage integration. This is a fixture,
-- not controller-only playthrough evidence. Only the fixture setup writes RAM.
local frame=0
local case=nil
local actor=8
local hits=0
local planted=false
local landed=false
local maxShots=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function phase() return case and frame-case.start or -1 end
emu.addEventCallback(function()
 local p=phase()
 emu.setInput({start=frame==120,up=p==3 or p==33 or p==63,b=p==3 or p==33 or p==63},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame>=700 and frame<=1140 and (frame-700)%220==0 then
  case={multiplier=math.floor((frame-700)/220),start=frame}
  hits=0;planted=false;landed=false;maxShots=0
  for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
  w(0x6001,2);w(0x600d,90);w(0x45,64);w(0x5b,0);w(0x46c,0);w(0x434,0);w(0x47,0)
  w(0x38c,128);w(0x40,128);w(0x41,0);w(0x3f,176);w(0x354,176);w(0x450,0)
  w(0x15b,11);w(0x15c,0);w(0x15d,0);w(0x71,30);w(0x64,0);w(0x603e,0);w(0x6020,0);w(0x6021,0)
  if case.multiplier>0 then
   local item=19
   for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530,0x4dc}) do w(base+item,0) end
   w(0x434+item,47);w(0x584+item,12);w(0x4c0+item,case.multiplier==1 and 47 or 48);w(0x31c+item,case.multiplier==1 and 82 or 83)
   w(0x38c+item,128);w(0x354+item,184)
  end
 end
 -- Give a real landed flame a native crow target. The projectile continues
 -- through its unmodified AI and collision/damage routines.
 if case and not planted then
  for x=20,22 do if r(0x434+x)==23 and r(0x46c+x)==2 then
   planted=true;landed=true
   for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530,0x514,0x4dc}) do w(base+actor,0) end
   w(0x434+actor,12);w(0x488+actor,8);w(0x31c+actor,61)
   w(0x38c+actor,r(0x38c+x));w(0x354+actor,r(0x354+x)-8)
   break
  end end
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if case and emu.getState()['cpu.x']==actor and r(0x0e)==3 then
  local flame=false
  for x=20,22 do if r(0x434+x)==23 and r(0x46c+x)==2 then flame=true end end
  assert(flame,'Holy water enemy hit must include a landed flame')
  assert(r(0x0d)==0 and r(0x0c)>0,'Holy water must supply native nonzero damage')
  hits=hits+1
 end
end,emu.callbackType.exec,0xe573)
emu.addEventCallback(function()
 frame=frame+1
 if not case then return end
 local p=phase()
 if p==1 then assert(r(0x15b)==11 and r(0x64)==case.multiplier,'Native II/III pickup must preserve holy water') end
 local shots=0
 for x=20,22 do if r(0x434+x)==23 then shots=shots+1 end end
 maxShots=math.max(maxShots,shots)
 assert(shots<=case.multiplier+1,'Holy water must respect native simultaneous projectile capacity')
 if p==100 then
  assert(maxShots==case.multiplier+1,'Real Up+B throws must use every unlocked holy water slot: '..case.multiplier..' max '..maxShots)
  assert(r(0x71)==30-case.multiplier-1,'Each accepted holy water throw must cost one heart: '..r(0x71))
  assert(landed and hits>0,'Landed holy water must damage the native enemy with multiplier '..case.multiplier)
  assert(r(0x434+actor)~=12,'Native enemy death handler must resolve holy water damage')
  assert(r(0x6020)==0 and r(0x6021)==0,'Up+B must not also create Mario fireballs')
  print('Holy water multiplier '..case.multiplier..' passed: '..maxShots..' simultaneous bottles/flames, one heart each, landed flame damage and native enemy death')
 end
 if p==200 and case.multiplier==2 then print('Holy water damage passed: single, II and III');emu.stop(0) end
 assert(frame<1400,'Holy water damage fixture timeout')
end,emu.eventType.endFrame)
