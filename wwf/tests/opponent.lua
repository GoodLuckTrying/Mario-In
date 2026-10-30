CHOICES={HUMAN or 0,OPPONENT or 0}
dofile(TEST_ROOT..'/tests/common.lua')
local nativeDraw=0;local nativeBrain=0;local frames=0;local last=nil;local gap=0
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end
if first then nativeDraw=nativeDraw+1 end end,emu.callbackType.exec,0xA62E)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if not first then return end
 nativeBrain=nativeBrain+1
 local t=f-first
 if t>=140 and t<460 then local s=emu.getState();s['cpu.pc']=0xB70B;emu.setState(s)end
end,emu.callbackType.exec,0xB6BB)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if first then if last then gap=math.max(gap,f-last)end;last=f;frames=frames+1 end
end,emu.callbackType.exec,0xABFF)
function input(t)return{b=t>=160 and t<340 and t%20==0}end
function tick(t)
 if t<0 then return end
 if t==140 then
  assert(r(0x2a)==(HUMAN or 0)and r(0x2b)==(OPPONENT or 0),'human identity and original opponent identity remain separate')
  assert(r(0x12d)==255 and r(0x12e)==0,'original CPU and controller 1 stay in their native slots')
  w(0x79,200);w(0x7a,200)
 end
 if t>=140 and t<460 then
  w(0x2d,80);w(0x2c,148);w(0x2e,180);w(0x2f,180);w(0x3b,0);w(0x3a,1)
  w(0x3c,0);w(0x3d,0);w(0x3e,0);w(0x3f,0)
 end
 if t==300 then screen('original-opponent-'..(OPPONENT or 0))end
 if t==450 then assert(r(0x7a)<125,'fireballs damage the right-hand original wrestler energy bar '..(OPPONENT or 0));assert(r(0x79)==200,'Mario/Luigi must keep their own left-hand energy while firing');assert(r(0x4b0)==0 and r(0x4b1)==0,'original CPU keeps native attacks without Mario fireballs')end
 if t==600 then
  assert(nativeDraw>500 and nativeBrain>100,'original opponent drawing/AI continue to execute');assert(gap<=1 and frames>590,'mixed original/Mario sprites keep every active frame')
  finish('original opponent '..(OPPONENT or 0)..' portrait/identity, native AI/graphics, real controller fire damage and stable split timing')
 end
end
