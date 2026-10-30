local f=0
local entered=nil
local arrival=0
local arrivalSaved=false
local arrivalY=nil
local nativeShots=0
local fireShots=0
local template=nil
local nativeHorizontal=false
local nativeUp=false
local bouncing=false
local pool=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function save(name)local o=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=(not entered and f%120<3)or t==150 or t==180,
 b=t==20 or t==32 or t==44 or t==56 or t==90 or t==110,
 up=t==90})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x1e)==3 then entered=entered or f end
 -- This check owns no contact state; normal enemies remain running except in
 -- the fixed-capacity shot fixture, where health is refilled separately.
 if entered then w(0x106,0);w(0x107,3)end
 local t=entered and f-entered or -1
 if t==110 and template then
  w(0x350,0);w(0x3c0,0)
  for _,x in ipairs({0xd0,0xe0,0xf0})do
   for i=0,15 do w(0x300+x+i,template[i+1])end
   w(0x300+x,1);w(0x30b+x,1);w(0x308+x,0);w(0x309+x,4)
   w(0x30c+x,r(0x30c));w(0x30d+x,100);w(0x30e+x,128);w(0x30f+x,255)
  end
 end
end,emu.callbackType.exec,N.UpdateWorld)
emu.addMemoryCallback(function()
 local x=emu.getState()['cpu.y']
 if x==0x50 or x==0xc0 then fireShots=fireShots+1 else nativeShots=nativeShots+1 end
end,emu.callbackType.exec,H.FireInit)
local pauseAges=nil
emu.addEventCallback(function()
 f=f+1
 if r(0x1e)==8 and r(H.M_POSE)==13 and r(0x200)<239 then
  for c=0,7 do
   local tile=r(H.MarioTiles+13*8+c)
   assert(r(0x201+c*4)==tile,'arrival uses complete front Mario pose')
   local rom=assert(io.open(TEST_ROOT..'/dist/Mario in Metroid.nes','rb'));rom:seek('set',16+6*16384+tile*16);local b=rom:read(16);rom:close()
   for i=0,15 do assert(emu.read(tile*16+i,emu.memType.nesPpuDebug)==b:byte(i+1),'arrival CHR agrees with candidate atlas')end
  end
  arrivalY=arrivalY or r(0x200)
  assert(r(0x200)==arrivalY,'palette fade states must not be mistaken for Small Mario and move the body')
  arrival=arrival+1
  if arrival>30 and not arrivalSaved then save('repaired-arrival');arrivalSaved=true end
 end
 if not entered then assert(f<1700,'arrival finishes');return end
 local t=f-entered
 for _,x in ipairs({0xd0,0xe0,0xf0})do
  if r(0x300+x)==1 then
   if not template then template={};for i=0,15 do template[#template+1]=r(0x300+x+i)end end
   if r(0x309+x)~=0 and r(0x308+x)==0 then nativeHorizontal=true end
   if r(0x309+x)==0 and r(0x308+x)>=128 then nativeUp=true end
  end
 end
 for _,x in ipairs({0x50,0xc0})do if r(0x300+x)==1 then
   if r(0x30b+x)~=0 then assert(r(0x301+x)==4 and r(0x302+x)==4,'independent fireball hitbox matches its visible size f='..f..' x='..x..' on='..r(0x30b+x)..' radius='..r(0x301+x)..','..r(0x302+x))end
   if r(0x6d00+x)>=128 then bouncing=true end
  end end
 if t==111 then
  assert(r(0x3d0)==1 and r(0x3e0)==1 and r(0x3f0)==1,'native three-shot pool remains full')
  assert(r(0x350)==1 or r(0x3c0)==1,'fireball can spawn while every native beam slot is occupied')
  pool=true;save('repaired-combined-shots')
 end
 if t==155 then pauseAges={r(0x35f),r(0x3cf)}end
 if t==175 then assert(r(0x1e)==5 and r(0x35f)==pauseAges[1] and r(0x3cf)==pauseAges[2],'pause freezes independent shot lifetimes')end
 if t==230 then
  assert(arrival>30 and arrivalSaved,'all visible arrival frames checked')
  assert(nativeShots>=5 and fireShots>=3,'B fires native and independent Mario projectiles')
  assert(nativeHorizontal and nativeUp,'horizontal and upward native shots retain their trajectories')
  assert(bouncing,'independent fireball bounces off native floor')
  assert(pool and r(0x1e)==3,'full-pool shot fixture and pause/resume finish')
  print('PASS '..arrival..' arrival frames, native horizontal/up shots, independent bouncing fireballs, full native pool and pause; shots '..nativeShots..'/'..fireShots)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
