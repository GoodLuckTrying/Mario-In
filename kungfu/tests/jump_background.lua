-- Mario is entirely sprites: stationary jumps and attacks must not rewrite
-- the wall, roof, floor, background colors or the other nametable.
local f=0
local stage=STAGE or 0
local reference=nil
local jumps=0
local previousAir=0
local done=false
local hurtJump=false
local visibleAir=0
local minFoot=255
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function background()
 local result={}
 for _,base in ipairs({0x2000,0x2400})do
  for a=base+9*32,base+0x3bf do result[#result+1]=emu.read(a,emu.memType.nesPpuDebug)end
 end
 for a=0x3f00,0x3f0f do result[#result+1]=emu.read(a,emu.memType.nesPpuDebug)end
 return result
end
emu.addMemoryCallback(function()w(0x58,stage)end,emu.callbackType.exec,0x8522)
emu.addEventCallback(function()
 local phase=(f-800)%120
 setPad(0,{start=f>=180 and f<190,up=f>=800 and (phase<26 or phase==60),down=f>=800 and phase>=90 and phase<110,b=f>=800 and f%37<3,a=f>=800 and f%51<3});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=700 then
  for i=0,5 do w(0x80+i,0)end
  w(0x373,0);w(0x374,0);w(0x7c01,1)
  if f>=800 then w(0x7c00,math.min(2,(f-800)//360))end
  if f==1160 then
   -- A live hurt recovery overlaps the next physical jump. The native
   -- engine has no combined hurt+air dispatch entry; Mario must reconcile it.
   w(0x69,(r(0x69)&1)|8);w(0x23,2);w(0x68,0);hurtJump=true
  end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f>=800 and r(0x7c08)~=0 and r(0x230)<240 then
  visibleAir=visibleAir+1;minFoot=math.min(minFoot,r(0x230))
 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if f==790 then reference=background()end
 if f>=800 then
  local now=background()
  for i=1,#reference do assert(now[i]==reference[i],'stationary jump/attack changed background tile or palette entry '..i..' on frame '..f)end
  local air=r(0x7c08)
  if air~=0 and previousAir==0 then jumps=jumps+1 end
  previousAir=air
 end
 if f==825 or f==1185 or f==1545 then
  local out=assert(io.open(TEST_ROOT..'/build/jump-floor-'..stage..'-frame-'..f..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==1880 then
  assert(jumps>=12,'test must exercise held and tapped jumps in all three forms')
  assert(hurtJump,'hurt recovery must overlap a physical jump')
  assert(visibleAir>200 and minFoot<150,'Mario must visibly rise in the rendered jump frames')
  assert(KUNGFU_GRAPHICS_CHECKS>800,'native graphics and VRAM commands must be checked throughout')
  print('PASS floor '..stage..' '..jumps..' stationary held/tapped jumps and attacks preserve background tiles/palettes in all forms')
  done=true;emu.stop(0)
 end
end,emu.eventType.endFrame)
