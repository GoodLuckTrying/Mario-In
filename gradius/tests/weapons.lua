local f=0
local weapon=WEAPON or 0
local options=OPTIONS or 0
local missile=MISSILE or 0
local fire=0
local laser=0
local missiles=0
local opt=0
local falling=0
local previous={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{start=f>=200 and f<210,a=f>=510,right=f>=620 and f<650});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<510 then return end
 for i=3,8 do
  local t=r(0x120+i)
  if t==6 or t==0x24 then
   if previous[i] and r(0x360+i)>previous[i][1] and r(0x320+i)>previous[i][2] then falling=falling+1 end
   previous[i]={r(0x360+i),r(0x320+i)}
  else previous[i]=nil end
 end
 for i=1,2 do if r(0x120+i)==4 or r(0x120+i)==5 then opt=opt+1 end end
 for i=9,11 do if r(0x120+i)~=0 then missiles=missiles+1 end end
end,emu.callbackType.exec,H.FireLoop)
emu.addMemoryCallback(function()
 if f<510 then return end
 for i=4,252,4 do
  local y=r(0x7100+i);local t=r(0x7101+i)
  if y<212 then
   if t==107 or t==115 then fire=fire+1;assert(r(0x7102+i)%4==3,'Fireball palette f '..f..' at '..i..' tile '..t..' y '..y..' attr '..r(0x7102+i)) end
   if weapon==1 and (t==0x6d) then laser=laser+1 end
  end
 end
end,emu.callbackType.exec,0x80aa)
emu.addEventCallback(function()
 f=f+1
 if f==490 then w(0x44,weapon);w(0x45,options);w(0x41,missile);w(0x7005,1);w(0x46,5) end
 if f==800 then
  if weapon~=1 then assert(fire>20 and falling>10,'Mario must throw visible falling fireballs')
  else assert(fire==0 and laser>20,'Laser upgrade must retain its native beam art') end
  if options>0 then assert(opt>30,'Options must retain native movement and shooting') end
  if missile>0 then assert(missiles>30,'Missile upgrade must still fire alongside the main attack') end
  assert(r(0x100)==1,'Barrier/invincibility fixture must remain playable')
  local out=assert(io.open(TEST_ROOT..'/build/weapon-'..weapon..'-'..options..'-'..missile..'.png','wb'));out:write(emu.takeScreenshot());out:close()
  print('PASS weapon '..weapon..' options '..options..' missile '..missile..' fire sprites '..fire..' falling '..falling);emu.stop(0)
 end
end,emu.eventType.endFrame)
