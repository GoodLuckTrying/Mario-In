-- Native level-2 manhole fixture: actual B input at a missing table entry
-- and at a real listed entry. Only placement/ground contact is fixed.
local f=0
local p=PLAYER or 0
local selected=false
local lookups=0
local found=0
local calls=0
local phase=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function word(lo,hi,n,v)w(lo+n,v);w(hi+n,v>>8)end
emu.addMemoryCallback(function()if not selected then w(0xaa,0);selected=true end end,emu.callbackType.exec,0x82BF)
emu.addEventCallback(function()
 local b=f>=950 and f<955 or f>=1150 and f<1155
 setPad(0,{start=f>=700 and f<710,b=p==0 and b});setPad(1,{b=p==1 and b})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 calls=calls+1
 if f>=900 and f<1250 then
  word(0x4d7,0x4c3,p,phase==0 and 0x379 or 0x348)
  word(0x4ff,0x4eb,p,0x115)
  word(0x527,0x513,p,0x90)
  w(0x5c7+p,255);w(0x5db+p,0);w(0x577+p,0)
  w(0x7000+p,2);w(0x40d+p,255)
 end
end,emu.callbackType.exec,H.SceneGate)
emu.addMemoryCallback(function()
 if f>=900 and f<1250 and emu.getState()['cpu.x']==p then w(0xc0,2);w(0x577+p,0)end
end,emu.callbackType.exec,0x9B96)
emu.addMemoryCallback(function()if f>=900 then lookups=lookups+1 end end,emu.callbackType.exec,H.ManholeLookup)
emu.addMemoryCallback(function()if f>=900 then found=found+1 end end,emu.callbackType.exec,0xCCF2)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if f>=800 then
  w(0x40d,255);w(0x40e,255)
  w(0x40f+p,0);w(0x409+p,0);w(0x48d+p,0);w(0x49b+p,p+1);w(0xaf,0)
 end
 if f==1050 then
  assert(lookups>0,'controller B reaches the missing manhole lookup')
  assert(found==0,'invalid entry must not open a different manhole')
  assert(calls>150,'game must continue updating after missing entry')
  phase=1;lookups=0
 end
 if f==1250 then
  assert(found>0,'valid listed manhole must still open with B')
  assert((r(0x1df)&15)==14,'native manhole consumed once')
  assert(r(0x7000+p)==2,'opening a manhole must retain Flower power')
  print('PASS P'..p..' missing manhole returns; real listed manhole opens through controller B')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
