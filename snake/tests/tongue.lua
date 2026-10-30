-- Native moving-food fixture. Body overlap must leave it alone; actual
-- controller B must capture/eat it, then run tongue and flower fire together.
local f=0
local p=PLAYER or 0
local slot=19
local captures=0
local rewards=0
local shots=0
local together=0
local oneups=0
local beforeLives
local beforeWeight
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function pos(lo,hi,n)return r(lo+n)+r(hi+n)*256 end
local function word(lo,hi,n,v)w(lo+n,v);w(hi+n,v>>8)end
emu.addEventCallback(function()
 local right=f>=908 and f<912
 local b=f==2120 or f==2145
 for i=0,3 do if f==920+i*300 or f==940+i*300 then b=true end end
 setPad(0,{start=f>=700 and f<710,right=p==0 and right,b=p==0 and b})
 setPad(1,{right=p==1 and right,b=p==1 and b})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=2020 and f<2100 and oneups==0 then
  if beforeLives==nil then beforeLives=r(0x3df+p)end
  w(0x49b+slot,0x1e);w(0x5b3+slot,0);w(0x5ef+slot,0);w(0x577+slot,0)
  word(0x4d7,0x4c3,slot,pos(0x4d7,0x4c3,p))
  word(0x4ff,0x4eb,slot,pos(0x4ff,0x4eb,p))
  word(0x527,0x513,slot,pos(0x527,0x513,p))
 end
 local meal=math.floor((f-820)/300)
 if f<820 or f>=2000 or captures>meal then return end
 if beforeWeight==nil then beforeWeight=r(0x59f+p)&63 end
 w(0x49b+slot,0x31);w(0x5b3+slot,meal%3);w(0x577+slot,0)
 local ahead=(f>=904 or meal>0) and 8 or 0
 word(0x4d7,0x4c3,slot,pos(0x4d7,0x4c3,p)+ahead)
 word(0x4ff,0x4eb,slot,pos(0x4ff,0x4eb,p)+ahead)
 word(0x527,0x513,slot,pos(0x527,0x513,p))
end,emu.callbackType.exec,H.SceneGate)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if s['cpu.x']==slot then
  assert(s['cpu.y']==p,'tongue capture credits its controller')
  assert(f>=920,'body overlap without B must never capture food')
  assert((r(0x41f+p)&127)>0,'capture requires an extended tongue')
  captures=captures+1
 end
end,emu.callbackType.exec,0xB385)
emu.addMemoryCallback(function()
 if captures>0 and f<2020 and emu.getState()['cpu.x']==p then rewards=rewards+1 end
end,emu.callbackType.exec,0x9D54)
emu.addMemoryCallback(function()if emu.getState()['cpu.y']==p then oneups=oneups+1 end end,emu.callbackType.exec,0xC1A6)
emu.addMemoryCallback(function()
 if f>=2110 then
  local first=p*2
  if r(0x7058+first)>0 or r(0x7059+first)>0 then
   shots=shots+1
   if (r(0x41f+p)&127)>0 then together=together+1 end
  end
 end
end,emu.callbackType.exec,H.FireDraw)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if f>=800 then w(0x40d,255);w(0x40e,255)end
 if f==900 then
  assert(captures==0,'standing on a Pibble must not collect it')
  assert((r(0x59f+p)&63)==beforeWeight,'touching food must not add weight')
 end
 for meal=1,4 do
  if f==800+meal*300 then
   assert(captures==meal,'B captures each Pibble once; count '..captures)
   assert(rewards==meal,'native eating rewards each meal once; count '..rewards)
   assert(r(0x7000+p)==math.min(2,math.floor(meal/2)),'two Pibbles per upgrade, regardless of color')
  end
 end
 if f==2110 then
  assert(oneups==1 and r(0x3df+p)==beforeLives+1,'native 1-Up must grant one life')
  assert(r(0x7000+p)==2,'native 1-Up must preserve Fire Flower power')
 end
 if f==2130 then
  local out=assert(io.open(TEST_ROOT..'/build/tongue-p'..p..'.png','wb'))
  out:write(emu.takeScreenshot());out:close()
 end
 if f==2250 then
  assert(shots>8,'Flower B must throw controller-fired fireballs')
  assert(together>0,'Flower B must also extend the native tongue')
  print('PASS P'..p..' tongue-only meals, two Pibbles per upgrade, native 1-Up retains flower, simultaneous attacks')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
