local f=0
local p=PLAYER or 0
local options=OPTIONS or 0
local max=0
local updates=0
local contacts=0
local sweeps=0
local first=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local function checkPools()
 local total=0
 for owner=0,options do
  local forward=(r(0x123+owner)~=0 and 1 or 0)+(r(0x7050+owner)~=0 and 1 or 0)
  local upward=(r(0x126+owner)~=0 and 1 or 0)+(r(0x7053+owner)~=0 and 1 or 0)
  assert(forward<=2 and upward<=2,'Each direction has its own two-shot cap')
  total=total+forward+upward
 end
 max=math.max(max,total)
 return total
end
emu.addEventCallback(function()
 for q=0,1 do
  setPad(q,{start=q==0 and f>=200 and f<210,a=q==p and ((f>=510 and f<513) or (f>=518 and f<521) or (f>=526 and f<529) or (f>=546 and f<549) or (f>=566 and f<569))})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=532 and f<610 then
  for owner=0,options do
   for _,s in ipairs({owner,owner+3}) do
    if r(0x123+s)~=0 then w(0x363+s,80);w(0x323+s,80);w(0x7020+s,0);w(0x7030+s,0) end
    if r(0x7050+s)~=0 then w(0x7070+s,80);w(0x7080+s,80);w(0x7090+s,0);w(0x70a0+s,0) end
   end
  end
 end
end,emu.callbackType.exec,H.FireGate)
emu.addMemoryCallback(function()
 if f>=500 then
  for s=12,31 do w(0x300+s,0);w(0x100+s,0);w(0x120+s,0) end
  if f<610 then checkPools() end
 end
end,emu.callbackType.exec,H.EarlyCombat)
emu.addMemoryCallback(function()if f>=550 and f<600 then contacts=contacts+1 end end,emu.callbackType.exec,0xc0c7)
emu.addMemoryCallback(function()if f>=550 and f<600 then sweeps=sweeps+1 end end,emu.callbackType.exec,H.ExtraSweep)
emu.addMemoryCallback(function()if f>=550 and f<600 then updates=updates+1 end end,emu.callbackType.exec,0x80b3)
emu.addEventCallback(function()
 f=f+1
 if f==500 then
  if p==1 then w(3,0x70);w(0xa,3) end
  w(0x18,p);w(0x44,2);w(0x45,options);w(0x7005,1);w(0x320,96);w(0x360,48);w(0x7041,0)
  w(0x160,0);for i=0,23 do w(0x7a0+i,48);w(0x7c0+i,96) end
  for owner=1,options do w(0x360+owner,48+owner*8);w(0x320+owner,96) end
 end
 if f==530 then assert(checkPools()==4*(options+1),'Two presses: total '..checkPools()..' native '..r(0x123)..','..r(0x124)..','..r(0x125)..','..r(0x126)..','..r(0x127)..','..r(0x128)..' extra '..r(0x7050)..','..r(0x7051)..','..r(0x7052)..','..r(0x7053)..','..r(0x7054)..','..r(0x7055)) end
 if f==540 then w(0x7053,0) end
 if f==555 then assert(checkPools()==4*(options+1),'Free upward slot must refill while forward slots stay full') end
 if f==560 then w(0x7050,0) end
 if f==580 then assert(checkPools()==4*(options+1),'Free forward slot must refill while upward slots stay full') end
 if f==610 then
  assert(max==4*(options+1) and contacts==updates and sweeps==updates,'Extra shots must not repeat player contact processing')
  assert(updates>=49,'Full DOUBLE pool must keep completing frames at 60 fps in this fixture')
  local out=assert(io.open(TEST_ROOT..'/build/double-'..p..'-'..options..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  print('PASS independent DOUBLE 2+2, controller '..p..' options '..options..' max '..max..' updates '..updates);emu.stop(0)
 end
end,emu.eventType.endFrame)
