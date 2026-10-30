local f=0
local p=PLAYER or 0
local power=POWER or 0
local base=0x6800+p*128
local booted=false
local held=false
local thrown=false
local minY=255
local throwAt=AIR and 750 or 790
local pickedThisPress=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addMemoryCallback(function(a,v)
 if MOVING and f>=720 and f<728 then
  if v~=0 then pickedThisPress=true end
  assert(not (v==0 and pickedThisPress),'Moving pickup must not release the object on the same B press')
 end
end,emu.callbackType.write,0x56+p)
emu.addEventCallback(function()
 for q=0,1 do
  setPad(q,{start=q==0 and not booted and f%90<4,b=q==p and ((f>=720 and f<728) or (f>=throwAt and f<throwAt+8)),up=q==p and UP and f>=throwAt-5 and f<throwAt+10,a=q==p and f>=740 and f<765,right=q==p and ((MOVING and f>=720 and f<728) or (f>=740 and f<780))})
 end
 if MOVING and f==719 then w(base+6,0x28);w(0x4f0+p,160) end
 if EDGE and f==785 then
  w(0x4f0+p,16);w(0x500+p,0);w(base+6,0);w(base+0xb,2);w(base+0xc,2);w(0x400+p,0x90)
 end
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then
  w(0x98,0)
  w(0x50,1)
  for q=0,1 do
   w(0x4d0+q,0x80);w(0x400+q,0xD0);w(0x54+q,0);w(0x56+q,0);w(0x5e+q,0)
   w(0x4f0+q,q==p and 160 or 40);w(0x500+q,0);w(0x510+q,180);w(0x520+q,5)
   w(0x6800+q*128,0x4D);w(0x6804+q*128,power);w(0x6805+q*128,0);w(0x6806+q*128,0);w(0x684C+q*128,2)
   w(0x69c4+q,0)
  end
  for q=2,15 do w(0x4d0+q,0) end
  -- Native apple, with ordinary native object update and pickup path.
  local s=15
  w(0x4d0+s,0x80);w(0x400+s,0x90);w(0x4e0+s,0x10);w(0x420+s,OBJECT or 0x26)
  w(0x4f0+s,174);w(0x500+s,0);w(0x510+s,180);w(0x520+s,5)
  w(0x570+s,0x81);w(0x560+s,0xFF);w(0x550+s,0xAB)
 end
 if f>=725 and f<790 then
  held=held or r(0x56+p)~=0
  minY=math.min(minY,r(0x510+p))
 end
 if f==730 then print('carry='..r(0x56+p));assert(held,'B must pick up native apple') end
 if f==throwAt+8 and OBJECT~=0x25 then assert(r(0x56+p)==0,'B must release even at the screen edge or during a jump') end
 if f==800 then
  thrown=r(0x56+p)==0
  print('object type '..r(0x4ef)..' y '..r(0x51f)..' min player y '..minY)
  if OBJECT==0x25 and not UP then
   assert(not thrown,'Heavy metal box retains the native held wall-smash action')
  else
   assert(thrown,'B must release the carried native object')
   if UP then assert(r(0x51f)<120,'Up+B must throw vertically upward') end
  end
  assert(minY<155,'Mario must jump while carrying')
  assert(r(base+4)==power,'Carrying/throwing preserves form')
  local o=io.open(TEST_ROOT..'/build/carry-'..p..'-'..power..'-'..tostring(UP)..'.png','wb');o:write(emu.takeScreenshot());o:close()
 end
 if f==850 then print('PASS carry jump throw player '..p..' form '..power..' up '..tostring(UP));emu.stop(0) end
end,emu.eventType.endFrame)
