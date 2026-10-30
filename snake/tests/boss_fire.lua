-- Native boss actor/HP fixture on the Moon stage. The position fixture
-- keeps the firing character close; attacks use physical controller B.
local f=0
local p=PLAYER or 0
local selected=false
local boss=nil
local hits=0
local done=false
local seeded=false
local bx,by,bz
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function pos(lo,hi,n)return r(lo+n)+r(hi+n)*256 end
local function word(lo,hi,n,v)w(lo+n,v);w(hi+n,v>>8)end
emu.addMemoryCallback(function()if not selected then w(0xaa,9);selected=true end end,emu.callbackType.exec,0x82BF)
emu.addEventCallback(function()
 setPad(0,{start=f>=700 and f<710,b=p==0 and f>=850 and f%6==0})
 setPad(1,{b=p==1 and f>=850 and f%6==0})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<820 or done then return end
 if not seeded then
  boss=2;seeded=true
  w(0x49b+boss,0x1a);w(0x5b3+boss,0);w(0x617+boss,0)
  w(0x5ef+boss,0);w(0x603+boss,0);w(0x5c7+boss,0);w(0x5db+boss,0);w(0x577+boss,0)
  word(0x4d7,0x4c3,boss,pos(0x4d7,0x4c3,p)+14)
  word(0x4ff,0x4eb,boss,pos(0x4ff,0x4eb,p)+14)
  word(0x527,0x513,boss,pos(0x527,0x513,p)+6)
  bx=pos(0x4d7,0x4c3,boss);by=pos(0x4ff,0x4eb,boss);bz=pos(0x527,0x513,boss)
 end
 for i=2,19 do if r(0x49b+i)==0x1a then boss=i end end
 if boss==nil or r(0x49b+boss)~=0x1a then return end
 word(0x4d7,0x4c3,boss,bx);word(0x4ff,0x4eb,boss,by);word(0x527,0x513,boss,bz)
 word(0x4d7,0x4c3,p,bx-14)
 word(0x4ff,0x4eb,p,by-14)
 word(0x527,0x513,p,bz-6)
 -- Up+Right projects horizontally right in the native isometric controls.
 w(0x7020+p,9);w(0x7000+p,2);w(0x40d+p,255)
end,emu.callbackType.exec,H.FireUpdate)
emu.addMemoryCallback(function()
 if boss~=nil and emu.getState()['cpu.y']==boss then
  assert(r(0x7022)>>1==p,'fireball damage credits its owner')
  hits=hits+1
 end
end,emu.callbackType.exec,H.FireHit)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if f==690 then w(0xb7,1)end
 if f>=800 then
  w(0x40d,255);w(0x40e,255)
  w(0x48d+p,0);w(0x40f+p,0);w(0x409+p,0);w(0x49b+p,p+1)
 end
 if boss~=nil and r(0x49b+boss)==0x18 then
  done=true
  assert(hits>=19,'boss must take repeated native HP damage')
  print('PASS P'..p..' controller fireballs defeat native Moon boss fixture, '..hits..' hits')
  emu.stop(0)
 elseif f==2000 then
  done=true
  assert(false,'Moon boss not defeated; slot '..tostring(boss)..' hits '..hits..' kind '..r(0x49b+boss)..' hp '..r(0x617+boss)..' scene '..r(0x11)..':'..r(0x10)..' paused '..r(0xda)..' menu '..r(0xaf))
 end
end,emu.eventType.endFrame)
