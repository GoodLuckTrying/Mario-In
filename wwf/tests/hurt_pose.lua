MODE=2;CHOICES={HUMAN or 0,(HUMAN or 0)~1}
dofile(TEST_ROOT..'/tests/common.lua')
local checks=0;local minHP=255;local actions=HUMAN==1 and{[9]=true,[10]=true}or{[8]=true,[9]=true}
function input(t)return{}end
function input2(t)return{a=t>=110 and t<800 and t%40==2}end
emu.addMemoryCallback(function()
 if r(0xc)~=4 then return end

 if not first or r(0xc)~=4 or not actions[r(0x3d)]then return end
 assert(r(0x4d9)==8,'ordinary injury must use a standing guard/flinch pose: frame '..(f-first)..' action '..r(0x3d)..' resolved '..r(0x6113)..' pose '..r(0x4d9))
 assert(r(0x4f0)==r(0x2d),'injury art must stay on the physical X anchor')
 assert(r(0x4f2)==((r(0x2f)-r(0x43)+r(0x31)-32)&255),'injury art must preserve actual height without original wrestler cell offsets')
 checks=checks+1
end,emu.callbackType.exec,H.Draw)
function tick(t)
 if t>100 then minHP=math.min(minHP,r(0x79))end
 if t==100 then
  w(0x2d,100);w(0x2c,120);w(0x2e,180);w(0x2f,180);w(0x3a,1);w(0x3b,0)
 end
 if t==200 then screen('injury-brother-'..(HUMAN or 0))end
 if t==850 then assert(checks>=6 and minHP<200,'real controller kicks produce verified injury frames: '..checks..' frames, minimum HP '..minHP);finish('native controller damage retains stable Mario/Luigi injury anchors and an upright flinch pose')end
end
