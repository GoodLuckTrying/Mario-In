local f=0
local seen={}
local samples={}
local expected=assert(io.open(TEST_ROOT..'/dist/Mario in Gradius.nes','rb')):read('*a')
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=(f>=200 and f<210) or (f>=650 and f<656) or (f>=710 and f<716),up=f%90<30})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<450 or r(0x100)~=1 then return end
 local phase=r(0x7046);assert(phase<=2,'Swimming animation phase must stay in range');seen[phase]=true
 for _,pair in ipairs({8,10,12,222}) do
  local at=16+32768+phase*4*8192+4096+pair*16
  for i=0,31 do assert(emu.read(0x1000+pair*16+i,emu.memType.nesPpuDebug)==expected:byte(at+i+1),'Hardware CHR must show the exact SMB swimming pose') end
 end
 if f>=500 and f<580 then
  if not samples['pose'..phase] then
   samples['pose'..phase]=true
   local out=assert(io.open(TEST_ROOT..'/build/swim-'..phase..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  end
 end
end,emu.callbackType.exec,0x8a80)
emu.addEventCallback(function()
 f=f+1
 if f==430 then w(0x7005,1) end
 if f==660 or f==700 then samples[f]={r(0x7045),r(0x7046)} end
 if f==780 then
  assert(seen[0] and seen[1] and seen[2],'All three original swimming poses must appear')
  assert(samples[660][1]==samples[700][1] and samples[660][2]==samples[700][2],'Swimming animation must freeze while paused')
  print('PASS three original SMB swimming poses, bus-safe CHR switching, pause');emu.stop(0)
 end
end,emu.eventType.endFrame)
