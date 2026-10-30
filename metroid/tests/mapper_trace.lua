local f=0
local entered=nil
local writes={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,a=t>60 and t%80<25});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()if not entered then entered=f;print('ENTER '..f)end end,emu.callbackType.exec,H.BeforeHandler)
emu.addMemoryCallback(function(a,v)
 if not entered then return end
 local s=emu.getState()
 writes[#writes+1]=string.format('f=%d pc=%04X addr=%04X v=%02X shift=%d sp=%02X nmi=%d defer=%d',f,s['cpu.pc'],a,v,s['mapper.shiftCount'],s['cpu.sp'],r(0x1a),r(0x6ca0))
 if #writes>64 then table.remove(writes,1)end
end,emu.callbackType.write,0x8000,0xFFFF)
emu.addMemoryCallback(function()
 if not entered then return end
 for _,v in ipairs(writes)do print(v)end
 print('RESET '..f)
 emu.stop(0)
end,emu.callbackType.exec,0xC01A)
emu.addEventCallback(function()f=f+1;if f==1500 then print('END');emu.stop(0)end end,emu.eventType.endFrame)
