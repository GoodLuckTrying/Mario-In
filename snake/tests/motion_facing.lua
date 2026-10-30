-- Real controller directions -> native isometric displacement -> hardware
-- Mario view/mirroring. The supplied sheet's noses point LEFT in the
-- canonical side and diagonal cells; right movement must mirror them.
local f=0;local snapshot=nil;local before={};local checks=0;local seen={};local moved={{},{}};local vectors={{},{}}
local directions={
 {bits=1,x=1,y=1,view=1,flip=64,pad={right=true}},
 {bits=5,x=0,y=1,view=0,flip=0,pad={right=true,down=true}},
 {bits=4,x=-1,y=1,view=1,flip=0,pad={down=true}},
 {bits=6,x=-1,y=0,view=2,flip=0,pad={left=true,down=true}},
 {bits=2,x=-1,y=-1,view=3,flip=0,pad={left=true}},
 {bits=10,x=0,y=-1,view=4,flip=0,pad={left=true,up=true}},
 {bits=8,x=1,y=-1,view=3,flip=64,pad={up=true}},
 {bits=9,x=1,y=0,view=2,flip=64,pad={right=true,up=true}}}
local fields={0x4c3,0x4d7,0x4eb,0x4ff,0x513,0x527,0x53b,0x54f,0x563,0x577,0x5c7,0x5db,0x65}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function world(p)return{r(0x4d7+p)+r(0x4c3+p)*256,r(0x4ff+p)+r(0x4eb+p)*256}end
local function phase()return(f-900)//96 end
local function direction(p)return directions[(phase()+p*4)%8+1]end
emu.addEventCallback(function()
 for p=0,1 do
  local pad={start=p==0 and f>=700 and f<710}
  if f>=900 and(f-900)%96<60 then for k,v in pairs(direction(p).pad)do pad[k]=v end end
  setPad(p,pad)
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f==850 and not snapshot then
  snapshot={{},{}};for p=0,1 do for _,a in ipairs(fields)do snapshot[p+1][a]=r(a+p)end end
  -- Move the fixture onto the middle of the same flat spawn platform.
  for p=1,2 do local x=snapshot[p][0x4d7]+snapshot[p][0x4c3]*256+24;snapshot[p][0x4d7]=x&255;snapshot[p][0x4c3]=x>>8 end
 end
 if f<900 or f>=3204 then return end
 for p=0,1 do
  -- Return to the native spawn every twelve frames to test all directions
  -- on the same terrain without turning this into an unassisted campaign.
  if(f-900)%12==0 then for a,v in pairs(snapshot[p+1])do w(a+p,v)end end
  w(0x7000+p,(phase()//8+p)%3);w(0x3df+p,9)
  w(0x49b+p,p+1);w(0x48d+p,0)
  w(0x40d+p,0);w(0x40f+p,0);w(0x409+p,0);w(0x40b+p,0)
  before[p+1]=world(p)
 end
end,emu.callbackType.exec,H.SceneGate)
emu.addMemoryCallback(function()
 if f<900 or(f-900)%96>=60 then return end
 for p=0,1 do if before[p+1]then
  local pos=world(p);local dx=pos[1]-before[p+1][1];local dy=pos[2]-before[p+1][2]
  local sx=dx+dy;local sy=dx-dy;local d=direction(p)
  local v=vectors[p+1][d.bits]or{0,0};v[1]=v[1]+sx;v[2]=v[2]+sy;vectors[p+1][d.bits]=v
  -- The fractional native axes can advance on different frames. Permit
  -- that one-pixel alternating projection on a cardinal direction.
  if(d.x==0 and math.abs(sx)<=1 or d.x*sx>0)and(d.y==0 and math.abs(sy)<=1 or d.y*sy>0)and(sx~=0 or sy~=0)then
   moved[p+1][d.bits]=true
  end
 end end
end,emu.callbackType.exec,H.FireUpdate)
emu.addMemoryCallback(function()
 if f<900 or f>=3204 or(f-900)%96<72 or(f-900)%96>=90 then return end
 for p=0,1 do
  local d=direction(p);local id=r(0x70a2+p);local power=(phase()//8+p)%3
  assert(r(0x7020+p)==d.bits,'raw controller facing retained independently')
  assert(id//25==power and(id%25)//5==d.view,'displayed view follows controller P'..p..' direction '..d.bits..' got '..id)
  assert(r(0x70a6+p)==d.flip,'canonical left-facing cells mirror only for right movement')
  local base=r(0x70ba+p)
  for cell=0,15 do assert(emu.read(base+cell*4+2,emu.memType.nesSpriteRam)&64==d.flip,'hardware sprite mirroring follows movement')end
  seen[power*16+d.bits]=true;checks=checks+1
 end
end,emu.callbackType.exec,0xff9c)
emu.addEventCallback(function()
 f=f+1;if f==690 then w(0xb7,1)end
 if f>=900 and f<3204 and(f-900)%96==85 then
  local out=assert(io.open(TEST_ROOT..'/build/motion-face-'..phase()..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==3204 then
  for p=1,2 do for _,d in ipairs(directions)do local v=vectors[p][d.bits]or{0,0};print('MOVEMENT',p,d.bits,v[1],v[2])end end
  for power=0,2 do for _,d in ipairs(directions)do
   assert(seen[power*16+d.bits],'all forms and eight rendered views')
   for p=1,2 do assert(moved[p][d.bits],'native projected movement exercised P'..p..' in each direction '..d.bits)end
  end end
  assert(checks>500,'sustained actual OAM checks')
  print('PASS both controllers: native displacement in eight directions, source-correct hardware facing in all three forms; '..checks..' rendered checks')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
