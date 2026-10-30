-- Real title, stage loader, CHR loader, player physics, native weapon menu and restart.
local f=0
local entered=nil
local steps=0
local frames=0
local jumps=0
local prevAir=0
local fired=0
local paused=false
local resumed=false
local baseY=nil
local minY=255
local jumpOrigin=nil
local maxRise=0
local sawConveyor=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function save(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
end
emu.addMemoryCallback(function()
 if r(0x29)==13 then
  local menu={8,3,1,4,2,7,5,6,0}
  for i,v in ipairs(menu)do if v==(STAGE or 2)then w(0x2a,i-1)end end
 end
end,emu.callbackType.exec,N.stage_select_loop)
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=(not entered and f%120<3) or (t==220) or (t==250),
  right=not entered and f%120>=10 and f%120<13,
  left=(STAGE==7 and t>=35 and t<60)or(STAGE==6 and t>=35 and not(t>=220 and t<250)),
  a=t>=30 and t%90<25,b=t>=30 and t%20<2})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x29)~=14 then return end
 if not entered then
  entered=f
  assert(r(0x2a)==(STAGE or 2),'native menu must load requested stage '..(STAGE or 2)..', actual '..r(0x2a))
  local file=assert(io.open(TEST_ROOT..'/build/code.bin','rb'));local bytes=file:read('*a');file:close()
  for i=1,#bytes do assert(r(0x6000+i-1)==bytes:byte(i),'boot loader code byte '..i)end
 end
 steps=steps+1
 if STAGE==6 and (r(0x40)&15)~=0 then sawConveyor=true end
 -- Keep stage terrain real; suppress enemies only for the stationary movement/CHR fixture.
 for i=16,31 do w(0x420+i,0)end
end,emu.callbackType.exec,H.Motion)
emu.addMemoryCallback(function()
 if entered then fired=fired+1 end
end,emu.callbackType.exec,N.weapon_spawn_projectile)
emu.addMemoryCallback(function()if entered then paused=true end end,emu.callbackType.exec,N.open_weapon_menu)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2000,'title/stage entry');return end
 local t=f-entered
 if t>30 then
  frames=frames+1
  local air=r(H.M_STATE)
  if air~=0 and prevAir==0 and r(0x701a)==0 then jumps=jumps+1;jumpOrigin=r(0x4a0)end
  prevAir=air
  if air==0 and r(0x701a)==0 then baseY=baseY or r(0x4a0)end
  if air~=0 and jumpOrigin then maxRise=math.max(maxRise,jumpOrigin-r(0x4a0))end
  minY=math.min(minY,r(0x4a0))
 end
 if t==110 or t==310 then save('stage-'..(STAGE or 2)..'-'..t)end
 if t==570 then
  assert(steps>380,'native main loop must continue after weapon menu')
  assert(r(H.M_MAGIC)==77,'initialized Mario state')
  assert(jumps>=4,'repeat held jumps')
  assert(fired>=10,'both native pellets and independent fireballs spawn repeatedly')
  assert(paused,'native Start weapon menu')
  assert(maxRise>=30,'visible variable jump, measured rise '..maxRise)
  assert(r(0x6c0)==28,'native energy meter preserved in enemy-free fixture')
  if STAGE==6 then assert(sawConveyor,'exercise real Metal Man conveyor tiles')end
  for _,tile in ipairs({1,2,3,4,5,6,7,8})do
   -- Compare player CHR against the candidate's patched ROM, never against an assumed frame.
   local rom=assert(io.open(TEST_ROOT..'/dist/Mario in Mega Man 2.nes','rb'));rom:seek('set',16+0x1000+tile*16);local bytes=rom:read(16);rom:close()
   for b=0,15 do assert(emu.read(tile*16+b,emu.memType.nesPpuDebug)==bytes:byte(b+1),'player CHR survives stage and menu loads')end
  end
  print('PASS stage '..(STAGE or 2)..': title/entry, RAM code, Mario CHR, '..jumps..' jumps, '..fired..' fireballs, native health and pause/resume')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
