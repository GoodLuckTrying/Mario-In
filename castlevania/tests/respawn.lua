local frame=0
local resets=0
local died=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local f=assert(io.open((TEST_ROOT..'/build/hack.lbl'),'r'))
local labels=f:read('*all');f:close()
local reset=assert(tonumber(labels:match('al (%x+) %.ResetMario'),16))
emu.addMemoryCallback(function() resets=resets+1 end,emu.callbackType.exec,reset)
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 then
  w(0x6001,2);w(0x600d,0);w(0x5b,0);w(0x45,8);w(0x46c,0)
  local x=19
  for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x60a0}) do w(base+x,0) end
  w(0x434+x,1);w(0x38c+x,r(0x38c));w(0x354+x,r(0x3f));w(0x31c+x,0x50)
  w(0x6020,1);w(0x602c,255);w(0x6022,200);w(0x6024,80);w(0x6071,40);w(0x6047,9);w(0x603e,24);w(0x6039,1)
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame==701 then
  assert(r(0x45)==0 and r(0x6001)==0,'Empty health must be lethal after powered Mario shrinks')
  assert(r(0x603e)==0 and r(0x6039)==0,'Damage must cancel the active whip')
  died=true
 end
 if died and resets>=2 and r(0x18)==5 and r(0x19)==6 and r(0x45)==64 then
  assert(r(0x6001)==0 and r(0x6071)==0 and r(0x6072)==0 and r(0x6020)==0 and r(0x6021)==0 and r(0x6047)==0 and r(0x603e)==0 and r(0x6039)==0,'Respawn must reset Mario, whip and projectile state')
  print('Death and native respawn reset passed at frame '..frame);emu.stop(0);return
 end
 if frame==1500 then print('FAIL missing native respawn');emu.stop(1) end
end,emu.eventType.endFrame)
