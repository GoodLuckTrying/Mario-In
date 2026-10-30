local f=0
local starts={}
local totals={}
local counts={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
local function now()return emu.getState().masterClock end
local function begin(k)if f>=800 then starts[k]=now()end end
local function finish(k)if starts[k]~=nil then totals[k]=(totals[k]or 0)+now()-starts[k];counts[k]=(counts[k]or 0)+1;starts[k]=nil end end
emu.addMemoryCallback(function()begin('actors')end,emu.callbackType.exec,0x8D03)
emu.addMemoryCallback(function()finish('actors')end,emu.callbackType.exec,0x8D06)
emu.addMemoryCallback(function()begin('draw')end,emu.callbackType.exec,0x8D5D)
emu.addMemoryCallback(function()finish('draw');finish('map')end,emu.callbackType.exec,0x8D60)
if NEW then
 emu.addMemoryCallback(function()begin('choose')end,emu.callbackType.exec,H.DrawStart)
 emu.addMemoryCallback(function()finish('choose')end,emu.callbackType.exec,0xFA31)
end
emu.addEventCallback(function()
 local a=f>=1010 and f<1030;local b=f>=920 and f<1010 and f%14<2
 setPad(0,{start=f>=700 and f<710,a=a,b=b});setPad(1,{a=a,b=b})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==690 then w(0xb7,1)end
 if f==850 then w(0x7000,1);w(0x7001,1)end
 if f==890 then w(0x7000,2);w(0x7001,2)end
 if f==1120 then
  for k,v in pairs(totals)do print(k,counts[k],v/counts[k]/12)end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
