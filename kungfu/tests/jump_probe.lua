local f=0
local hits=0
local seen={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=f>=180 and f<190,up=f>=800 and f<830 or f>=880 and f<910});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=700 then
  for i=0,5 do w(0x80+i,0)end
  w(0x373,0);w(0x374,0)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>=790 then print('ANIM',f,r(0x69),r(0x68),r(0x21),r(0x7c08),r(0xb6),r(0x52))end
end,emu.callbackType.exec,0xA8EB)
emu.addMemoryCallback(function()
 if f>=790 then
  local index=r(0x52);local ptr=r(0x8056+index)+256*r(0x80a5+index)
  if index>=0x4f and not seen[index] then seen[index]=true;print('BAD-COMMAND',f,index,ptr,r(0x69),r(0x68))end
 end
end,emu.callbackType.exec,0x82EE)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if f>=790 and s['ppu.scanline']>=0 and s['ppu.scanline']<240 and hits<10 then hits=hits+1;print('VISIBLE-VRAM',f,s['ppu.scanline'],s['cpu.pc'])end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==815 or f==850 or f==920 then local o=assert(io.open(TEST_ROOT..'/build/jump-'..f..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if f==1000 then emu.stop(0)end
end,emu.eventType.endFrame)
