-- Reproduce the video failures with real native AI, defeat and OAM passes.
local f=0
local case=0
local hit=false
local removed=false
local knifeFrames=0
local scenes=0
local cases={
 {kind=0,shot=false},{kind=1,shot=false},{kind=2,shot=false},
 {kind=10,shot=false},{kind=11,shot=false},{kind=12,shot=false},{kind=13,shot=false},
 {kind=0,shot=true},{kind=1,shot=true},{kind=2,shot=true},
 {kind=10,shot=true},{kind=11,shot=true},{kind=12,shot=true},{kind=13,shot=true},
}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local original=assert(io.open('C:/nes/Kung Fu (Japan, USA) (En).nes','rb')):read('*a')
local function spawn(slot,kind,dx,y,hp)
 for _,a in ipairs({0xc7,0xb7,0x486,0x490,0x498,0x4a8,0x410,0x4b0,0x4b8,0x3f,0x2b})do w(a+slot,0)end
 w(0x80+slot,1);w(0x87+slot,kind);w(0x4a0+slot,hp or 0)
 w(0xb0+slot,y);w(0x8e+slot,r(0x94)+dx);w(0x9f+slot,1);w(0xc0+slot,dx<0 and 1 or 0)
 local world=r(0xd4)+256*r(0xe5)+dx
 w(0xce+slot,world);w(0xdf+slot,world>>8)
end
emu.addMemoryCallback(function()
 if f<700 then w(0x7c01,255);return end
 local elapsed=f-700
 if elapsed<#cases*160 and elapsed%160>4 then w(0x7c01,200);for i=1,4 do w(0x80+i,0)end;if removed then w(0x80,0)end end
 if elapsed%160==0 and elapsed//160<#cases then
  if case>0 then assert(hit and removed,'enemy '..case..' must die, fall/remove and free its native slot')end
  case=elapsed//160+1;print("Case "..case.." frame "..f);hit=false;removed=false
  for i=0,4 do w(0x80+i,0)end
  w(0x7c00,0);w(0x7c01,0);w(0x7c0c,0);w(0x4a6,48);w(0x69,1);w(0x68,0)
  w(0x7c24,0);w(0x7c25,0);w(0x7d01,0);w(0x7d02,0)
  local c=cases[case];local y=c.kind>=10 and 169 or 135
  spawn(0,c.kind,0,y)
  if c.shot then
   w(0x7c08,0);w(0x7c04,135);w(0xb6,135);w(0x7c01,120)
   w(0x7c24,20);w(0x7c20,r(0x94)-4);w(0x7c22,y+4);w(0x7c26,4);w(0x7c28,0);w(0x7c2a,0)
  else
   local yy=y>=169 and 124 or 94
   w(0x7c08,1);w(0x7c04,yy);w(0xb6,yy);w(0x7c05,2);w(0x7c06,0);w(0x7c07,0)
  end
 end
 if elapsed>=#cases*160 and elapsed<#cases*160+100 then
  if elapsed==#cases*160 then assert(hit and removed,'last enemy lifecycle');case=#cases+1 end
  -- Throw a real native knife while Mario uses an extended punch bank.
  for i=0,4 do w(0x80+i,0)end
  w(0x7c00,2);w(0x7c01,100);w(0x7c04,135);w(0x7c08,0);w(0xb6,135)
  w(0x69,0x11);w(0x68,1);w(0x21,10)
  w(0x3ec,0x10);w(0x3d4,40);w(0x3d0,160)
 end
 if elapsed==#cases*160+110 then
  for i=0,4 do w(0x80+i,0)end
  spawn(0,0,0,135);w(0x7c00,1);w(0x7c01,0);w(0x7c0c,0);w(0x7c08,0);w(0x7c04,135);w(0xb6,135)
 end
 if elapsed==#cases*160+112 then
  assert(r(0x7c00)==0 and r(0x7c01)>0,'ordinary enemy contact must shrink Mario without a permanent grab')
  w(0x80,0);spawn(5,3,12,135,48);w(0x7e,1);w(0x7c00,1);w(0x7c01,0);w(0x7c0c,0)
 end
 if elapsed==#cases*160+114 then
  assert(r(0x7c00)==0 and r(0x7c01)>0,'boss body contact must hurt small-height Mario')
  w(0x7c00,0);w(0x7c01,0);w(0x7c0c,0);spawn(5,3,12,135,48)
 end
 if elapsed==#cases*160+116 then
  assert(r(0x4a6)>=128,'unprotected small Mario must die on boss contact')
  assert(knifeFrames>=50,'native knives must be visible through extended Mario punch art')
  print('PASS '..#cases..' native enemy stomp/fireball lifecycles; no frozen grabs; visible original knife CHR; ordinary and boss body damage')
  emu.stop(0)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 local x=emu.getState()['cpu.x']
 if x==0 and case<=#cases and r(0x4a0)>=128 then hit=true end
end,emu.callbackType.exec,0xC479)
emu.addMemoryCallback(function()
 if case>#cases and r(0x7c0f)==5 then
  local seen=false
  for a=0x250,0x2fc,4 do if r(a)<240 and r(a+1)==0x0a then seen=true end end
  if seen then
   for n=0,15 do assert(emu.read(0xa0+n,emu.memType.nesPpuDebug)==original:byte(0x80b1+n),'knife pixels must remain native while Mario punches')end
   knifeFrames=knifeFrames+1
  end
 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()setPad(0,{start=f>=180 and f<190})end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f>700 and case>0 and case<=#cases then
  if hit and r(0x80)==0 then removed=true end
  assert(r(0x80)&4==0,'Mario contact must not orphan a native gripper stack')
  if not cases[case].shot and (f-700)%160<5 then assert(r(0x4a6)<128,'stomp must precede enemy contact damage: f '..f..' case '..case..' y '..r(0xb6)..' old '..r(0x7c09)..' vy '..r(0x7c05)..' hit '..tostring(hit)..' enemyHP '..r(0x4a0))end
 end
 assert(f<3300,'combat scenarios finish')
end,emu.eventType.endFrame)
