-- Controlled collision-map fixtures: body height, ceilings and screen bounds.
local frame=0
local roofs={}
for _,speed in ipairs({0,40}) do for power=0,2 do
 roofs[#roofs+1]={start=720+90*#roofs,power=power,speed=speed,minimum=255}
end end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function tile(x,y,value)
 local addr=0x5a0+(y-48-y%8)+math.floor(x/32)
 local shift=(3-math.floor(x/8)%4)*2
 local old=r(addr)
 local mask=3*2^shift
 w(addr,old-(math.floor(old/2^shift)%4)*2^shift+value*2^shift)
end
local function seed(power,speed)
 for a=0x5a0,0x6ff do w(a,0) end
 for x=0,255,8 do tile(x,192,1) end
 w(0x38c,80);w(0x3a8,0);w(0x40,80);w(0x41,0);w(0x2e,0);w(0x2f,0);w(0x3c,4);w(0x3f,176);w(0x354,176);w(0x46c,0)
 w(0x6001,power);w(0x6070,0);w(0x6071,speed);w(0x6072,0);w(0x6073,speed);w(0x6076,1);w(0x6077,1);w(0x607f,0);w(0x6004,0);w(0x6005,0);w(0x6006,0)
end
emu.addEventCallback(function()
 local jump=false
 for _,case in ipairs(roofs) do if frame>=case.start and frame<case.start+35 then jump=true end end
 emu.setInput({start=frame==120,right=frame==700 or frame==710,b=frame==700 or frame==710,a=jump},0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 or frame==710 then seed(frame==700 and 0 or 1,40);tile(88,168,1) end
 for _,case in ipairs(roofs) do
  if frame==case.start then seed(case.power,case.speed);for x=0,255,8 do tile(x,144,1) end end
  if frame>case.start and frame<=case.start+60 then case.minimum=math.min(case.minimum,r(0x3f)) end
 end
 if frame==701 and r(0x40)<=80 then print('FAIL small body hit a wall above its head');emu.stop(1);return end
 -- SMB moves before contact, using center+5 rather than Simon's predictive
 -- center+8. The first two-pixel step has not reached this eight-pixel wall.
 if frame==711 then assert(r(0x40)==82 and r(0x6071)==40,'SMB must reach its side probe before blocking') end
 if frame==712 then assert(r(0x40)>=82 and r(0x40)<=84 and r(0x6071)==0,'Big body must stop on actual upper-side contact') end
 if frame==roofs[#roofs].start+70 then
  for _,case in ipairs(roofs) do
   print('Thin ceiling: power '..case.power..', speed '..case.speed..', minimum Y '..case.minimum)
   -- Centered SMB head probes are Y+2 (small) and Y-12 (grown).
   -- Each native eight-pixel roof must be detected by that head probe.
   local head=case.minimum+(case.power==0 and 2 or -12)
   assert(head>=144 and head<152,'Skipped thin ceiling at power '..case.power..', speed '..case.speed)
  end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
emu.addMemoryCallback(function() if frame>=700 then for x=3,23 do w(0x434+x,0);w(0x60a0+x,0) end end end,emu.callbackType.exec,0xcf19)
