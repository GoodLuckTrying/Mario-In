local frame=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function enemy(y)
 local x=10
 for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584}) do w(base+x,0) end
 w(0x434+x,1); w(0x38c+x,r(0x38c)); w(0x354+x,y); w(0x31c+x,0x50)
end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 then
  w(0x6001,1); w(0x600d,0); w(0x5b,0)
  w(0x3f,130); w(0x354,130); w(0x6008,128); w(0x6005,2); w(0x6004,0); w(0x46c,1)
  enemy(160)
 elseif frame==710 then
  w(0x6001,2); w(0x600d,0); w(0x5b,0); w(0x46c,0); w(0x3f,176); w(0x354,176)
  enemy(176)
 elseif frame==720 then
  w(0x6001,0); w(0x600d,0); w(0x5b,0); w(0x46c,0); w(0x3f,176); w(0x354,176); enemy(176)
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then assert(r(0x6045)==1,'Stomp must register'); assert(r(0x6005)>=128,'Stomp must bounce'); print('Stomp passed') end
 if frame==711 then assert(r(0x6001)==2,'Healthy enemy collision must retain Mario power'); assert(r(0x45)==56,'Enemy hit must remove native health'); assert(r(0x600d)>0,'Damage grants invincibility'); print('Power retention and health damage passed') end
 if frame==721 then assert(r(0x45)==48,'Small Mario must survive while health remains'); print('Small Mario health damage passed'); emu.stop(0) end
end,emu.eventType.endFrame)
