local f=0
local fired=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=f>=180 and f<190});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<800 then for i=0,5 do w(0x80+i,0)end end
 if f>=800 and not fired then
  fired=true;w(0x7c00,0);w(0x7c01,0);w(0x7c0c,0);w(0x4a6,0);w(0x37a,1)
  local s=emu.getState();s['cpu.x']=6;s['cpu.pc']=H.DamageGate;emu.setState(s)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f>=790 and f%10==0 then print('DEATH',f,r(0x50),r(0x51),r(0x4a6),r(0x86),r(0xb6),r(0x48c),r(0x388),r(0x5c),r(0x52),r(0x300))end
 if f==900 or f==1100 then
  local out=assert(io.open(TEST_ROOT..'/build/death-'..f..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==1500 then emu.stop(0)end
end,emu.eventType.endFrame)
