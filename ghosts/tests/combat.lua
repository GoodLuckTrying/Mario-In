dofile(TEST_ROOT..'/tests/graphics_oracle.lua')
local f=0
local entered=nil
local phase='jump'
local seeded=nil
local phaseAt=0
local deadZombies=0
local hurt=0
local armor=false
local death=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function save(n)local o=assert(io.open(TEST_ROOT..'/build/combat-'..n..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
local function actor(x,kind,flags,dx,y,sub)
 w(0x4f0+x,flags);w(0x631+x,kind);w(0x647+x,0);w(0x61d+x,sub or 0);w(0x607+x,80);w(0x65d+x,0)
 w(0x5af+x,r(0x5af)+dx);w(0x583+x,r(0x583));w(0x599+x,y);w(0x56d+x,r(0x56d));w(0x5f1+x,12)
 w(0x554+x,r(0x554)+dx);w(0x509+x,y-r(0x67));w(0x522+x,0x54);w(0x53b+x,0x0b);w(0x5c5+x,0);w(0x5db+x,0)
end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,a=phase=='jump' and t>=60 and t<115});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f
 if phase=='jump' and not seeded then for x=1,16 do w(0x4f0+x,0)end end
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 if not entered then return end
 if phase=='jump' and not seeded and f-entered>75 and r(H.M_STATE)~=0 and r(H.M_VY)<128 and r(0x599)<160 then
  for x=1,16 do w(0x4f0+x,0)end
  actor(1,0,0xa2,0,184);actor(2,0,0xa2,12,184)
  seeded=f;print('seed descending jump at y '..r(0x599))
 end
 if phase=='side' and not seeded then
  for x=1,16 do w(0x4f0+x,0)end
  actor(1,0,0xa2,6,r(0x599));seeded=f
 end
 if phase=='armor' and not seeded then
  for x=1,16 do w(0x4f0+x,0)end
  actor(1,0x10,0x84,0,r(0x599),5);seeded=f
 end
 if phase=='lethal' and not seeded then
  for x=1,16 do w(0x4f0+x,0)end
  w(0x4f0,(r(0x4f0)&0x9e)|0x20);w(0x647,0)
  actor(1,0,0xa2,0,r(0x599));seeded=f
 end
end,emu.callbackType.exec,0x9cc8)
emu.addMemoryCallback(function()
 if phase=='jump' then deadZombies=deadZombies+1;save('stomp')end
end,emu.callbackType.exec,0xf8c5)
emu.addMemoryCallback(function()
 if entered then hurt=hurt+1;print('hurt '..hurt..' phase '..phase)end
end,emu.callbackType.exec,N.PlayerHurt)
emu.addMemoryCallback(function()if entered then death=true;save('death')end end,emu.callbackType.exec,0xe1d7)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2000,'combat enters');return end
 if phase=='jump' and deadZombies>0 and f-seeded>100 then
  assert(r(0x4f0)&0x21==0,'stomp and adjacent enemy do not shrink/hurt Mario')
  assert(hurt==0,'stomp has priority over native body damage')
  phase='side';phaseAt=f;seeded=nil
 elseif phase=='side' and r(0x4f0)&0x20~=0 and r(H.M_NATIVE)==0 then
  assert(hurt==1,'real enemy side contact causes one armor loss')
  phase='waitArmor';phaseAt=f;save('small')
 elseif phase=='waitArmor' and f-phaseAt>130 then
  assert(r(H.M_FORM)==32,'small form reaches renderer and physics')
  phase='armor';seeded=nil;phaseAt=f
 elseif phase=='armor' and r(0x4f0)&0x20==0 then
  armor=true;phase='waitDeath';phaseAt=f;save('restored')
 elseif phase=='waitDeath' and f-phaseAt>50 then
  assert(r(H.M_FORM)==0,'native armor pickup restores Fire Mario')
  phase='lethal';seeded=nil;phaseAt=f
 elseif phase=='lethal' and death then
  phase='respawn';phaseAt=f
 elseif phase=='respawn' and f-phaseAt>300 and r(H.M_NATIVE)==0 and r(H.M_LIVE)==1 then
  assert(armor and deadZombies>0 and hurt>=2,'native collision, armor and death all exercised')
  print('PASS real A jump, native zombie AI stomp/defeat, adjacent protection, native side hit/shrink, armor pickup and lethal hit/respawn');assertMarioGraphics();emu.stop(0)
 end
 assert(f-entered<2500,'combat completes; phase '..phase..' hurt '..hurt..' deaths '..tostring(death))
end,emu.eventType.endFrame)
