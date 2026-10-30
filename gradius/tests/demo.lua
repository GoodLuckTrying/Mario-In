local f=0
local mario=0
local moved=0
local last=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0)==2 and r(0x7001)==1 and r(0x7000)==1 then
  assert(r(0x7105)==9 and r(0x7109)==11 and r(0x710d)==13 and r(0x7111)==223,'Demo must draw the complete Mario body')
  mario=mario+1
  local xy=r(0x7002)*256+r(0x7003);if last and last~=xy then moved=moved+1 end;last=xy
 end
end,emu.callbackType.exec,0x80aa)
emu.addEventCallback(function()
 f=f+1
 if f==2500 then assert(mario>100 and moved>10,'Attract Mario frames '..mario..' moved '..moved..' mode '..r(0)..' demo '..r(9));print('PASS native attract demo '..mario..' visible frames');emu.stop(0) end
end,emu.eventType.endFrame)
