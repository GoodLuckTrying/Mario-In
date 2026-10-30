local f=0
local entered=nil
local prepared=false
local hit=false
local enemy=nil
local t0=nil
local contact=0
local beforeEnergy=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function energy()return r(0x107)*16+(r(0x106)>>4)end
local function save(name)local o=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
emu.addEventCallback(function()
 local t=t0 and f-t0 or -1
 setPad(0,{start=not entered and f%120<3,a=t>=10 and t<35})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x1e)~=3 then return end
 entered=entered or f
 if not prepared and f-entered>40 then
  for x=16,80,16 do
   if r(0x6af4+x)==2 and r(0x6b02+x)==5 then enemy=x;break end
  end
  if enemy then
   -- Put an initialized native crawler on the starting floor route once,
   -- before the whole enemy/player update. Its AI and Mario's jump then run
   -- normally, without changing velocity or previous feet at contact.
   local x=enemy
   w(0x400+x,184);w(0x401+x,180);w(0x40A+x,0);w(0x405+x,r(0x405+x)|1)
   local anim=N.EnAnim_ZoomerOnFloor_BANK1-N.EnAnimTable_BANK1
   w(0x6af9+x,anim);w(0x6afa+x,anim);w(0x6af8+x,0)
   print('SET crawler '..x..' x='..r(0x401+x)..' y='..r(0x400+x)..' mario '..r(0x30e)..','..r(0x30d))
   w(0x30e,r(0x401+x)-30);w(0x30c,r(0x6afb+x));w(0x30d,176)
   w(0x70,0);w(0x30a,0);w(0x300,1);w(0x314,0)
   for i=1,46 do w(0x6c74+i,0)end
   w(0x6c7b,1);w(0x6c7c,1);w(0x6c82,1);w(0x6c83,8);w(0x6c8b,0x70)
   beforeEnergy=energy();prepared=true;t0=f
  end
 end
end,emu.callbackType.exec,N.UpdateWorld)
emu.addEventCallback(function()
 f=f+1
 if enemy and not hit and r(0x40e+enemy)==0x81 then hit=true;save('real-crawler-stomp');assert(energy()==beforeEnergy,'real descending stomp precedes damage')end
 if t0 and f-t0>100 then
  save('stomp-approach-final')
  assert(hit,'native crawler stomp reached from real A jump')
  assert(r(0x6af4+enemy)==0 or r(0x6af4+enemy)==3 or r(0x6af4+enemy)==5 or r(0x40b+enemy)==0,'native crawler defeated')
  print('PASS real jump approach, native crawler AI, stomp bounce and defeat');emu.stop(0)
 end
 assert(f<2500,'native crawler available for stomp replay')
end,emu.eventType.endFrame)

