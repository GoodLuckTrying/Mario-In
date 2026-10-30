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
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function save(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
end
emu.addMemoryCallback(function()
 if r(0x29)==14 then w(0x2a,STAGE or 2)end
end,emu.callbackType.exec,N.game_init_refill)
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=(not entered and f%120<3) or (t==220) or (t==250),
  right=not entered and f%120>=10 and f%120<13,
  a=t>=30 and t%90<25,b=t>=30 and t%20<2})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x29)~=14 then return end
 if not entered then
  entered=f
  local file=assert(io.open(TEST_ROOT..'/build/code.bin','rb'));local bytes=file:read('*a');file:close()
  for i=1,#bytes do assert(r(0x6000+i-1)==bytes:byte(i),'boot loader code byte '..i)end
 end
 steps=steps+1
 -- Keep stage terrain real; suppress enemies only for the stationary movement/CHR fixture.
 for i=16,31 do w(0x420+i,0)end
end,emu.callbackType.exec,H.Motion)
emu.addMemoryCallback(function()
 if entered then fired=fired+1 end
end,emu.callbackType.exec,H.FireSpawn)
emu.addMemoryCallback(function()if entered then paused=true end end,emu.callbackType.exec,N.open_weapon_menu)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2000,'title/stage entry');return end
 local t=f-entered
 if t>=30 and t<70 then print('J '..t..' y '..r(0x4a0)..' a '..r(H.M_STATE)..' vy '..r(H.M_VY)..' frac '..r(H.M_VY_FRAC)..' sub '..r(0x2c)..' ladder '..r(0x35)..' floor '..r(0x32)..','..r(0x33))end
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
  assert(fired>=10,'native default weapon repeatedly shoots fireballs')
  assert(paused,'native Start weapon menu')
  assert(maxRise>=30,'visible variable jump, measured rise '..maxRise)
  assert(r(0x6c0)==28,'native energy meter preserved in enemy-free fixture')
  for _,tile in ipairs({1,2,3,4,5,6,7,8})do
   -- Compare player CHR against the candidate's patched ROM, never against an assumed frame.
   local rom=assert(io.open(TEST_ROOT..'/dist/Mario in Mega Man 2.nes','rb'));rom:seek('set',16+0x1000+tile*16);local bytes=rom:read(16);rom:close()
   for b=0,15 do assert(emu.read(tile*16+b,emu.memType.nesPpuDebug)==bytes:byte(b+1),'player CHR survives stage and menu loads')end
  end
  print('PASS stage '..(STAGE or 2)..': title/entry, RAM code, Mario CHR, '..jumps..' jumps, '..fired..' fireballs, native health and pause/resume')
  emu.stop(0)
 end
end,emu.eventType.endFrame)

emu.addMemoryCallback(function() if entered and f-entered>35 and f-entered<40 then print('SUP floor '..r(0)..' C '..(emu.getState()['cpu.ps'] or -1)..' Y '..r(0x4a0)..' X '..r(0x460)..' pp '..r(0x2e))end end,emu.callbackType.exec,0x60a7)
