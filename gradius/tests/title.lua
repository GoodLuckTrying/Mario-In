local f=0;local checks=0;local ys={}
local original=assert(io.open('C:/nes/Gradius (USA).nes','rb')):read('*a')
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{select=(f>=190 and f<193)or(f>=220 and f<223),start=f>=250 and f<253})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<170 or f>=245 or r(0)~=1 then return end
 for a=0,8191 do assert(emu.read(a,emu.memType.nesPpuDebug)==original:byte(0x8010+3*8192+a+1),'title background and pointer patterns must exactly match the original ROM')end
 checks=checks+1
end,emu.callbackType.exec,0x80aa)
emu.addEventCallback(function()
 f=f+1
 if f==180 or f==205 or f==235 then
  assert(r(0)==1,'title selector remains visible')
  ys[f]=r(0x320)
  assert(r(0x0f)==(f==205 and 1 or 0),'Select chooses the correct native player-count option')
  local file=assert(io.open(TEST_ROOT..'/build/title-pointer-'..f..'.png','wb'));file:write(emu.takeScreenshot());file:close()
 end
 if f==450 then
  assert(checks>=60 and ys[180]~=ys[205]and ys[180]==ys[235],'the intact pointer moves to both entries and back')
  assert(r(0)==5 and r(0x100)==1,'Start launches the selected game normally')
  print('PASS original title/pointer pixels, native selector movement and Start');emu.stop(0)
 end
 assert(f<500,'bounded title replay')
end,emu.eventType.endFrame)
