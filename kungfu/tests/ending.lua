-- Clear the actual fifth-floor boss and follow the Sylvia ending.
local f=0
local entered=nil
local endingFrames=0
local storyFrames=0
local bossDead=false
local saved=false
local done=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()w(0x58,4)end,emu.callbackType.exec,0x8522)
emu.addMemoryCallback(function()if f>=700 and not entered then w(0x7c00,2);w(0x7c01,255)end end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()if emu.getState()['cpu.x']==5 and r(0x4a5)>=128 then bossDead=true end end,emu.callbackType.exec,0xC479)
emu.addEventCallback(function()
 local go=f>=700 and not entered and r(0x51)==2
 local left=r(0x372)==0
 setPad(0,{start=f>=180 and f<190,left=go and left,right=go and not left,b=go and f%8<7})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not entered then return end
 if r(0x50)==1 and r(0x51)==3 then
  endingFrames=endingFrames+1
  assert(r(0x7c0f)==24,'final-floor ending must use Fire Mario idle art')
  assert(r(0x218)<240,'Mario must remain visible beside Sylvia f '..f..' native phase '..r(0x60)..' y '..r(0xb6)..' hp '..r(0x4a6)..' actor '..r(0x86)..' pose '..r(0x7c0f))
  assert((r(0x21a)&64)==(r(0xc6)==0 and 64 or 0),'ending must face its scripted direction')
  assert(r(0x7c24)==0 and r(0x7c25)==0,'ending cannot retain frozen fireballs')
  for i=0,5 do if r(0x87+i)==8 then assert(r(0x4a0+i)<128,'Sylvia must not be treated as a stomp/fireball target')end end
 elseif r(0x50)==1 then
  storyFrames=storyFrames+1
  if storyFrames>=3 and r(0x52)==0 then
   assert(r(0x7c3a)==35,'story hearts must use the original native bank')
   local file=assert(io.open('C:/nes/Kung Fu (Japan, USA) (En).nes','rb'));local old=file:read('*a');file:close()
   for n=0,15 do assert(emu.read(0x90+n,emu.memType.nesPpuDebug)==old:byte(0x80a1+n),'native story heart pixels must not become Mario body cells')end
  end
  for a=0x218,0x24c,4 do assert(r(a)>=240,'non-playable story screen must not display a stray Mario')end
 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if not entered and r(0x50)==1 and r(0x51)==3 then assert(bossDead,'real fifth-floor boss must be defeated');entered=f end
 if entered and endingFrames>=120 and not saved then
  local out=assert(io.open(TEST_ROOT..'/build/final-ending.png','wb'));out:write(emu.takeScreenshot());out:close();saved=true
 end
 if entered and r(0x50)==1 and r(0x51)==6 and storyFrames>=30 then
  assert(endingFrames>=120,'native ending must finish')
  print('PASS real final boss, Mario/Sylvia ending, scripted facing and clean story screen; ending '..endingFrames..' story '..storyFrames)
  done=true;emu.stop(0)
 end
 assert(f<8000,'final ending completes')
end,emu.eventType.endFrame)
