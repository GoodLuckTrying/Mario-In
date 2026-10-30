-- Full-energy controller defeat -> coordinate-only bottom-rope placement
-- -> real Down+A -> native Up kick-out -> free movement and real melee.
MODE=2
local actor=ACTOR or 1;local target=actor~1;local brother=HUMAN or 0
CHOICES=actor==1 and{brother,brother~1}or{brother~1,brother}
dofile(TEST_ROOT..'/tests/common.lua')
local downAt=nil;local placed=false;local pinAt=nil;local released=nil
local hitAt=nil;local hitHP=nil;local movement=false;local hud=nil
local function hero(t)
 if released then return{up=t-released<100}end
 if pinAt or placed then return{down=true,a=true}end
 if t<140 then return{}end
 if r(0xa2+target)~=0 then downAt=downAt or t;return{}end
 local dx=r(0x2c+target)-r(0x2c+actor);local dy=r(0x2e+target)-r(0x2e+actor)
 if math.abs(dy)<=1 and r(0x3a+actor)~=(dx>0 and 0 or 1)then return{right=dx>0,left=dx<0}end
 return{b=t%20==1,up=dy < -1,down=dy > 1,right=(math.abs(dx)>85 and dx>0)or(math.abs(dx)<50 and dx<0),left=(math.abs(dx)>85 and dx<0)or(math.abs(dx)<50 and dx>0)}
end
local function opponent(t)
 if hitAt then return{a=(t-hitAt)%24==1}end
 return{up=pinAt and not released and t%4==1}
end
function input(t)return actor==1 and hero(t)or opponent(t)end
function input2(t)return actor==0 and hero(t)or opponent(t)end
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first then return end
 local t=f-first
 if not placed and downAt and t-downAt>=150 and r(0xa2+target)==1 then
  placed=true
  w(0x2c+target,128);w(0x2e+target,199);w(0x2c+actor,120);w(0x2e+actor,190)
 end
 if r(0x4f6+actor)~=0 and not pinAt then pinAt=t end
 if pinAt and r(0xa2+target)==0 and not released then released=t end
 if released and t-released==100 then
  assert(r(0x2e+actor)<=190,'after a native kick-out the pinner must be able to leave the bottom rope; got Y='..r(0x2e+actor))
  assert(r(0x4f6+actor)==0 and r(0xe7+actor)==0,'native recovery must release custom pin/input locks')
  movement=true;screen('rope-recovery-p'..actor..'-brother'..brother)
 end
 if movement and not hitAt and t-released>=110 and r(0x3c+actor)<=4 and r(0x3c+target)<=4 then
  hitAt=t;hitHP=r(0x79+(actor~1))
  w(0x2c+actor,100);w(0x2c+target,120);w(0x2e+actor,185);w(0x2e+target,185)
  w(0x3a+actor,0);w(0x3a+target,1)
 end
 if hitAt and t-hitAt>=120 then
  assert(r(0x79+(actor~1))<hitHP,'the recovered pinner must take damage from real native controller kicks')
  assert(downAt and pinAt and released and movement,'all native defeat/pin/kick-out/reentry stages must run')
  finish('full-energy defeat, bottom-rope pin, native kick-out, inward walking, subsequent native damage and intact HUD')
 end
end,emu.callbackType.exec,H.UpdateBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not pinAt or released then return end
 -- Select the RNG outcome for an otherwise legal native Up kick-out.
 -- Do not seed health, defeat flags, script state, referee count or victory.
 if emu.getState()['cpu.x']==target and r(0xe+r(0x12d+target))==8 and r(0xa4+actor)==2 then w(0x82,0xf8)end
end,emu.callbackType.exec,H.ControlBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first then return end
 local t=f-first
 if t==60 then hud={};for a=0,0xbff do hud[a]=emu.read(a,emu.memType.nesPpuDebug)end end
 if hud and t%4==0 then for a=0,0xbff do
  assert(emu.read(a,emu.memType.nesPpuDebug)==hud[a],'complete HUD/portrait CHR must survive native defeat, pin and recovery')
 end end
end,emu.callbackType.exec,0xadfe)
function tick(t)assert(t<2200,'bounded native rope-pin recovery and subsequent combat')end
