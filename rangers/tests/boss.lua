local f=0
local booted=false
local p=PLAYER or 0
local base=0x6800+p*128
local hits=0
local maximum=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for q=0,1 do setPad(q,{start=q==0 and not booted and f%90<4,b=q==p and f>=720 and f<1300 and f%8<4}) end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<700 or emu.getState()['cpu.x']~=15 then return end
 -- Hold the boss in the attack plane while retaining native health,
 -- vulnerability, hit cooldown and defeat/level-clear routines.
 w(0x4ff,150);w(0x50f,0);w(0x51f,180);w(0x52f,5);w(0x40f,0xD0)
end,emu.callbackType.exec,H.ObjectHitGate)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then
  w(0x98,0);w(0x50,1);w(0xed,0);w(0xee,0);w(0xef,15)
  for q=0,1 do
   w(0x4d0+q,q==p and 0x80 or 0);w(0x54+q,0);w(0x56+q,0);w(0x400+q,0xD0)
   w(0x4f0+q,110);w(0x500+q,0);w(0x510+q,180);w(0x520+q,5)
   w(0x684c+q*128,2);w(0x69c4+q,0)
  end
  w(base,0x4d);w(base+4,2);w(base+5,0);w(base+6,0);w(base+0xb,1);w(base+0x14,1);w(base+0x15,8);w(base+0x35,0)
  for s=2,15 do w(0x4d0+s,0) end
  for a=0x40f,0x58f,16 do w(a,0) end
  w(0x4df,0x80);w(0x40f,0xD0);w(0x4ef,0x40);w(0x42f,0x70);w(0x57f,0x17)
  w(0x4ff,150);w(0x50f,0);w(0x51f,180);w(0x52f,5)
 end
 if f>700 then w(0x5e+p,120);maximum=math.max(maximum,r(0xee)) end
 if f==1350 then
  print('native boss hits '..maximum..' clear '..r(0x6d))
  assert(maximum>=5,'Fireballs must deliver five native boss hits through the cooldown')
  assert(r(0x6d)>0 or r(0x4df)==0,'Native boss defeat/level clear must run')
  print('PASS native boss fireball damage player '..p);emu.stop(0)
 end
end,emu.eventType.endFrame)
