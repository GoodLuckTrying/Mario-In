local frame=0
local ram=assert(io.open(TEST_ROOT..'/build/native-ram.bin','wb'))
local oam=assert(io.open(TEST_ROOT..'/build/native-oam.bin','wb'))
local function dump(name,a,n,kind)
 local file=assert(io.open(TEST_ROOT..'/build/'..name,'wb'))
 for i=0,n-1 do file:write(string.char(emu.read(a+i,kind)))end
 file:close()
end
emu.addEventCallback(function()
 local t=frame
 local p={start=t==120 or(t<180 and t%60==5),right=t>=210 and t<270,left=t>=270 and t<300,a=t>=320 and t<350,b=t>=390 and t<430,up=t>=450 and t<480,down=t>=500 and t<530}
 setPad(0,p)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 local bytes={};for i=0,2047 do bytes[#bytes+1]=string.char(emu.read(i,emu.memType.nesDebug))end;ram:write(table.concat(bytes))
 bytes={};for i=0,255 do bytes[#bytes+1]=string.char(emu.read(i,emu.memType.nesSpriteRam))end;oam:write(table.concat(bytes))
 if frame%30==0 then
  local file=assert(io.open(TEST_ROOT..'/build/native-'..frame..'.png','wb'));file:write(emu.takeScreenshot());file:close()
  dump('native-'..frame..'.chr',0,8192,emu.memType.nesPpuDebug)
  dump('native-'..frame..'.pal',0x3f00,32,emu.memType.nesPpuDebug)
 end
 if frame==600 then
  local out=assert(io.open(TEST_ROOT..'/build/state.txt','w'));for k,v in pairs(emu.getState())do out:write(k..'='..tostring(v)..'\n')end;out:close()
  ram:close();oam:close();print('PASS native cold boot, controller and graphics discovery');emu.stop(0)
 end
end,emu.eventType.endFrame)
