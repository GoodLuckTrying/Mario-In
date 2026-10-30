local f=0
local entered=nil
local updates=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,right=not STILL and t>60 and t%300<130,left=not STILL and t>60 and t%300>=200,a=t>60 and t%80<25,b=not NO_FIRE and t>60 and t%16<2});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 updates=updates+1
 if not entered then entered=f;print('ENTER '..f)end
 for _,spec in ipairs({{'code-a.bin',0x7400,0x3F0},{'code-b.bin',0x7900,0x700}})do
  local file=assert(io.open(TEST_ROOT..'/build/'..spec[1],'rb'));local bytes=file:read('*a');file:close()
  for i=1,#bytes do assert(r(spec[2]+i-1)==bytes:byte(i),'code modified '..spec[1]..' byte '..i..' f '..f)end
 end
end,emu.callbackType.exec,H.BeforeHandler)
emu.addMemoryCallback(function()
 if entered then print('RESET f '..f..' health '..r(0x106)..','..r(0x107)..' sub '..r(0x300))end
end,emu.callbackType.exec,0xFFB0)
emu.addEventCallback(function()
 f=f+1
 if f%120==0 then print('F '..f..' bank '..r(0x23)..' routine '..r(0x1e)..' samus '..r(0x300)..' xy '..r(0x30e)..','..r(0x30d)..' magic '..r(H.M_MAGIC)..' air '..r(H.M_STATE))end
 if entered and (f-entered==120 or f-entered==220 or f-entered==400) then
  local out=assert(io.open(TEST_ROOT..'/build/probe-'..(f-entered)..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==2400 then assert(updates>100,'must enter game');print('PASS boot probe '..updates);emu.stop(0)end
end,emu.eventType.endFrame)
