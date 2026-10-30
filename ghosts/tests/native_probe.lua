local f=0
local counts={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function save(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..(CAPTURE_PREFIX or 'native')..'-'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 local ram=assert(io.open(TEST_ROOT..'/build/'..(CAPTURE_PREFIX or 'native')..'-'..name..'.ram','wb'))
 for a=0,0x7ff do ram:write(string.char(r(a)))end;ram:close()
 local chr=assert(io.open(TEST_ROOT..'/build/'..(CAPTURE_PREFIX or 'native')..'-'..name..'.chr','wb'))
 for a=0,0x1fff do chr:write(string.char(emu.read(a,emu.memType.nesPpuDebug)))end;chr:close()
end
emu.addEventCallback(function()
 setPad(0,{start=f>=120 and f<650 and f%120<3,right=f>=1800 and f<1910,a=f>=1930 and f<1955,b=f>=2000 and f%20<2});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(a,v)
 local pc=emu.getState()['cpu.pc'];local key=string.format('%d:%04X',r(0xc7),pc)
 counts[key]=(counts[key]or 0)+1
end,emu.callbackType.exec,0xc000,0xc000)
emu.addEventCallback(function()
 f=f+1
 if f==650 or f==900 or f==1100 or f==1300 or f==1945 then save(f)end
 if f==2200 then
  local out=assert(io.open(TEST_ROOT..'/build/native-exec.json','w'));out:write('{')
  local comma='';for k,v in pairs(counts)do out:write(comma..'"'..k..'":'..v);comma=','end
  out:write('}');out:close();print('PASS native boot/gameplay research capture');emu.stop(0)
 end
end,emu.eventType.endFrame)
