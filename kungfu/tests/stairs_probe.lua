local f=0
local entered=nil
local last=-1
local native=0
local stage=STAGE or 0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addMemoryCallback(function()if f>=700 then w(0x7c00,2);w(0x7c01,1)end end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()if entered and emu.getState()['cpu.x']==6 then native=native+1 end end,emu.callbackType.exec,0xB2D5)
emu.addEventCallback(function()
 local left=r(0x372)==0
 setPad(0,{start=f>=180 and f<190,left=f>=700 and r(0x51)==2 and left,right=f>=700 and r(0x51)==2 and not left,b=f>=700 and r(0x51)==2 and f%8<7})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x51)==3 and entered==nil then entered=f;print('ENTER',f,r(0x69),r(0x7c08),r(0x7c0f))end
 if entered then
  if r(0x60)~=last then last=r(0x60);print('SCRIPT',f,r(0x51),last,r(0x86),r(0xb6),r(0x8d),r(0xbd),r(0x69),r(0x7c0f),'native',native)end
  if r(0x60)==3 and f%60==0 then
   print('OAM',r(0x94),r(0xb6),r(0x218),r(0x219),r(0x21b),r(0x230),r(0x233),r(0x10),r(0x63))
   local out=assert(io.open(TEST_ROOT..'/build/stairs-old-'..stage..'-'..f..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  end
  if f-entered>1300 then print('END',f,r(0x51),r(0x5f),'native',native);emu.stop(0)end
 end
 if f==6500 then assert(entered~=nil,'stairs must start');emu.stop(1)end
end,emu.eventType.endFrame)
