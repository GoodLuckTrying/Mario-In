-- Start normally and inspect Mario through the actual scripted entrance.
local f=0
local stage=STAGE or 0
local entered=nil
local visible=0
local checked=0
local firstX=nil
local lastX=nil
local done=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local file=assert(io.open(TEST_ROOT..'/build/mario-frames.chr','rb'));local frames=file:read('*a');file:close()
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addEventCallback(function()setPad(0,{start=f>=180 and f<190});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x50)~=1 or r(0x51)~=1 then return end
 if not entered then entered=f end
 if f-entered<3 then return end
 assert(r(0x218)<240,'Mario must be visible during the opening entrance: floor '..stage..' frame '..f)
 local pose=r(0x7c3a)
 assert(pose==23 or pose==12 or pose==13 or pose==14,'opening entrance must show small Mario idle/walking art, pose '..pose)
 local flip=r(0x21a)&64
 for cell=0,7 do
  local tile=r(0x219+cell*4);local logical=flip~=0 and cell~1 or cell
  for n=0,15 do assert(emu.read(tile*16+n,emu.memType.nesPpuDebug)==frames:byte(pose*128+logical*16+n+1),'visible entrance CHR floor '..stage..' f '..f..' command '..r(0x52)..' wanted '..pose..' loaded '..r(0x7c3a)..' cell '..cell..' n '..n)end
 end
 visible=visible+1;checked=checked+128
 firstX=firstX or r(0x21b);lastX=r(0x21b)
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if entered and visible>=12 and f%20==0 and not saved then
  local out=assert(io.open(TEST_ROOT..'/build/entrance-floor-'..stage..'.png','wb'));out:write(emu.takeScreenshot());out:close();saved=true
 end
 if entered and r(0x50)==1 and r(0x51)==2 then
  assert(visible>=20 and checked>=2560,'native entrance must repeatedly display Mario before control begins')
  assert(firstX~=lastX,'Mario must follow the scripted entrance movement')
  print('PASS floor '..stage..' opening entrance: '..visible..' visible Mario frames, native movement and '..checked..' verified CHR bytes')
  done=true;emu.stop(0)
 end
 assert(f<1000,'opening entrance finishes')
end,emu.eventType.endFrame)
