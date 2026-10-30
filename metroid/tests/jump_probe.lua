-- Real boot, native input/updates and isolated native equipment/contact fixtures.
local f=0
local entered=nil
local checks=0
local active=0
local minY=255
local jumpOrigin=0
local rises={0,0,0}
local sawSmall=false
local sawBomb=false
local sawMissile=false
local sawIce=false
local sawWave=false
local pauseSeen=false
local oldHealth=nil
local stomped=false
local sideDamaged=false
local spikyDamaged=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local B=0x6c74
local code={}
for _,spec in ipairs({{'code-a.bin',0x7400},{'code-b.bin',0x7900}})do
 local file=assert(io.open(TEST_ROOT..'/build/'..spec[1],'rb'));local bytes=file:read('*a');file:close();code[#code+1]={spec[2],bytes}
end
local function energy()return r(0x107)*16+(r(0x106)>>4)end
local function clearShots()for _,p in ipairs({0xd0,0xe0,0xf0})do w(0x300+p,0)end end
local function assertCode()
 for _,spec in ipairs(code)do for i=1,#spec[2]do assert(r(spec[1]+i-1)==spec[2]:byte(i),'private code damaged')end end
end
local function save(name)local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 local pad={start=not entered and f%120<3}
 if entered then
  pad.a=t==10 or (t>=90 and t<115) or (t>=180 and t<205)
  pad.down=(t>=300 and t<303)or(t>=315 and t<318)
  pad.up=t>=400 and t<403
  pad.b=(t==350 or t==365 or t==450 or t==490 or t==530 or t==570)
  pad.select=t==440 or t==470
  pad.start=t==600 or t==630
 end
 setPad(0,pad);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x23)~=1 or r(0x1e)~=3 then return end
 -- Isolate these motion/equipment checks from ordinary enemy AI.
 local t=entered and f-entered or -1
 for i=0,5 do
  if not(i==0 and ((t>=670 and t<674)or(t>=700 and t<704)or(t>=730 and t<734)))then w(0x6af4+i*16,0)end
 end
end,emu.callbackType.exec,N.UpdateWorld)
emu.addMemoryCallback(function()
 active=active+1
 if not entered and (r(0x300)==255 or r(0x300)<5) then entered=f;assertCode();jumpOrigin=r(0x30d)end
 if not entered then return end
 local t=f-entered
 if t==170 then w(0x6878,2)end
 if t==290 then w(0x6878,0)end
 if t==310 then w(0x6878,0x10)end
 if t==360 then w(0x6878,0x11)end
 if t==430 then clearShots();w(0x6879,5);w(0x687a,5)end
 if t==480 then clearShots();w(0x6878,0x90)end
 if t==520 then clearShots();w(0x6878,0x50)end
 if t==560 then clearShots();w(0x6878,0x14)end
end,emu.callbackType.exec,H.BeforeHandler)
emu.addMemoryCallback(function()
 if not entered then return end
 local t=f-entered
 if t~=670 and t~=700 and t~=730 then return end
 clearShots();w(0x6878,0);w(0x70,0);w(0x30a,0);w(B+25,0)
 w(0x30d,100);w(0x301,15);w(0x302,6);w(0x30c,r(0xff)&1)
 w(0x400,t==700 and 100 or 122);w(0x401,r(0x30e));w(0x40b,2);w(0x40f,0);w(0x404,0)
 w(0x6af4,2);w(0x6af5,8);w(0x6af6,8);w(0x6afb,r(0x30c));w(0x6b02,t==730 and 5 or 6)
 w(B+24,t==700 and 100 or 96);w(B+20,t==700 and 0 or 1);w(B+1,1)
 oldHealth=energy()
end,emu.callbackType.exec,N.CollisionDetection)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<1600,'native start/intro finishes');return end
 local t=f-entered
 if t<30 then print('T '..t..' y='..r(0x30d)..' radius='..r(0x301)..' state='..r(B+1)..' vy='..r(B+20)..' vsub='..r(B+21)..' frac='..r(B+37)..' native='..r(B+26)..' status='..r(0x300))end
 if t>=10 and t<80 then rises[1]=math.max(rises[1],jumpOrigin-r(0x30d))end
 if t>=90 and t<160 then rises[2]=math.max(rises[2],jumpOrigin-r(0x30d))end
 if t>=180 and t<280 then rises[3]=math.max(rises[3],jumpOrigin-r(0x30d))end
 if t==280 then
  assert(rises[1]>=20 and rises[1]<=26,'short jump '..rises[1]);checks=checks+1
  assert(rises[2]>=60 and rises[2]<=66,'held jump '..rises[2]);checks=checks+1
  assert(rises[3]>rises[2]+25,'High Jump Boots '..rises[3]);checks=checks+1
  assert(energy()==48,'native 30 energy unchanged in controlled fixture');checks=checks+1
 end
 if t==307 then assert(r(0x300)~=3,'Small Mario requires the Morph Ball upgrade');checks=checks+1 end
 if t>=320 and t<350 and r(0x300)==3 then sawSmall=true end
 if t>=365 and t<390 then for _,p in ipairs({0xd0,0xe0,0xf0})do if r(0x300+p)>=8 and r(0x300+p)<=10 then sawBomb=true end end end
 if t==420 then assert(r(0x300)~=3 and r(0x301)==15,'Up returns to full-height Mario');checks=checks+1 end
 if t>=450 and t<460 and r(0x3d0)==11 then sawMissile=true end
 if t>=490 and t<500 then for _,p in ipairs({0xd0,0xe0,0xf0})do if r(0x300+p)==3 then sawIce=true end end end
 if t>=530 and t<540 then for _,p in ipairs({0xd0,0xe0,0xf0})do if r(0x300+p)==2 then sawWave=true end end end
 if t>602 and t<629 and r(0x1e)==5 then pauseSeen=true end
 if t==671 then assert(r(B+20)>=0x80,'stomp bounces Mario');assert((r(0x404)&0x20)~=0 and r(0x40e)==0x81,'stomp routes through native damage handler');assert(energy()==oldHealth,'stomp must precede contact damage');stomped=true;checks=checks+3 end
 if t==673 then assert(r(0x6af4)==3 or r(0x6af4)==5 or r(0x40b)==0,'native enemy stomp defeat');checks=checks+1 end
 if t==701 then assert(energy()<oldHealth,'side contact uses native damage');sideDamaged=true;checks=checks+1 end
 if t==731 then assert(energy()<oldHealth,'spiky crawler remains dangerous');assert(r(0x40b)>0,'spiky crawler cannot be stomped');spikyDamaged=true;checks=checks+2 end
 if t==130 or t==330 then save('gameplay-'..t)end
 if t==780 then
  assert(sawSmall and sawBomb,'native Morph Ball/Small Mario and bombs');checks=checks+2
  assert(sawMissile and sawIce and sawWave,'native missiles, Ice Beam, Wave Beam');checks=checks+3
  assert(pauseSeen and r(0x1e)==3,'pause/resume');checks=checks+1
  assert(stomped and sideDamaged and spikyDamaged,'all contact fixtures ran')
  assertCode();checks=checks+1
  print('PASS Metroid '..checks..' checks; jumps '..table.concat(rises,',')..'; Small Mario, bombs, missiles, beams, contact and pause/resume')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
