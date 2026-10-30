local f=0
local p=PLAYER or 0
local speed=SPEED or 0
local samples={}
local shots=0
local reset=false
local resetchecked=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()
 for q=0,1 do
  setPad(q,{start=q==0 and ((f>=200 and f<210) or (f>=650 and f<656) or (f>=700 and f<706)),
   up=q==p and ((f>=540 and f<585) or (f>=640 and f<740)),a=q==p and f>=540 and f<585})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()if f>=540 and f<585 then shots=shots+1 end end,emu.callbackType.exec,H.SpawnAEnd)
emu.addMemoryCallback(function()
 if f<750 or reset then return end
 reset=true;w(0x7040,240);w(0x7041,1)
 if speed==4 then
  w(0x20+p,3);w(0x100,2);w(0x1b,0xa0);w(0x4c,2);w(0x4d,0)
 else w(0x1b,0) end
end,emu.callbackType.exec,0x80b3)
emu.addMemoryCallback(function()
 if not reset or resetchecked then return end
 assert(r(0x7041)==0 and r(0x7040)==0,'Native respawn/stage intro must reset vertical momentum')
 resetchecked=true
end,emu.callbackType.exec,H.FloatStep)
emu.addEventCallback(function()
 f=f+1
 if f==500 then
  if p==1 then w(0x03,0x70);w(0x0a,3) end -- Native separate-controller two-player mode.
  w(0x18,p);w(0x7005,1);w(0x320,60);w(0x340,0);w(0x7040,0);w(0x7041,0);w(0x40,speed);w(0x45,2)
 end
 if f==510 or f==530 or f==540 or f==585 or f==620 or f==660 or f==690 or f==720 then samples[f]={r(0x320),r(0x160),r(0x7040)} end
 if f==750 then
  assert(samples[530][1]>samples[510][1]+25,'Released Up must allow sustained gravity')
  assert(samples[585][1]<samples[540][1]-10,'Holding Up must reverse a fall and lift Mario')
  assert(samples[620][1]>samples[585][1],'Releasing Up must resume falling')
  assert(samples[510][2]~=samples[530][2],'Options must track gravity movement with no D-pad held')
  assert(shots>0,'A must throw fireballs while Up supplies lift')
  assert(samples[660][1]==samples[690][1] and samples[660][3]==samples[690][3],'Pause must freeze position and vertical momentum')
  assert(samples[720][1]<samples[690][1],'Up lift must resume after unpausing')
 end
 if f==840 then
  assert(resetchecked,'Native restart must return to gravity-controlled Mario')
  print('PASS gravity, Up lift, A fire, Options, pause and restart controller '..p..' speed '..speed);emu.stop(0)
 end
end,emu.eventType.endFrame)
