local f=0
local stage=STAGE or 0
local updates=0
local splits=0
local late=0
local skipped=0
local heldFrames=0
local maxReady=-1
local maxShots=0
local started=-1
local drawCycles=0
local maxDraw=0
local marks={}
local maxLate=-1
local contactStart=0
local maxContact=0
emu.addMemoryCallback(function()contactStart=emu.getState()['cpu.cycleCount']end,emu.callbackType.exec,0xc0c7)
emu.addMemoryCallback(function()maxContact=math.max(maxContact,emu.getState()['cpu.cycleCount']-contactStart)end,emu.callbackType.exec,H.ContactDone)
for _,pc in ipairs({0x80a7,0x80aa,0x9a64,0x9a6a,0x9a6d,0x9a70,0x9a73,0x9a79}) do
 emu.addMemoryCallback(function()local s=emu.getState();marks[pc]={s['cpu.cycleCount'],s['ppu.scanline']} end,emu.callbackType.exec,pc)
end
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f>=200 and f<210,a=f>=610,up=f>=600 and r(0x320)>88,right=f>=700 and f%600<80,left=f>=700 and f%600>=300 and f%600<380})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=610 then
  local s=emu.getState()
  if r(4)~=0 then skipped=skipped+1 end
 end
end,emu.callbackType.exec,0x8073)
emu.addMemoryCallback(function()
 if f>=610 then drawCycles=emu.getState()['cpu.cycleCount'] end
end,emu.callbackType.exec,0x80a7)
emu.addMemoryCallback(function()
 if f>=610 then maxDraw=math.max(maxDraw,emu.getState()['cpu.cycleCount']-drawCycles) end
end,emu.callbackType.exec,0x80aa)
emu.addMemoryCallback(function()
 if f>=610 and started~=f then
  started=f
  local sl=emu.getState()['ppu.scanline']
  maxReady=math.max(maxReady,sl)
 end
end,emu.callbackType.exec,0x9aa3)
emu.addMemoryCallback(function()
 if f>=610 then
  splits=splits+1
  local sl=emu.getState()['ppu.scanline']
  if sl<210 or sl>212 then
   late=late+1
   if sl>maxLate then
    maxLate=sl
    local msg='LATE f '..f..' split '..sl
    for _,pc in ipairs({0x80a7,0x80aa,0x9a64,0x9a6a,0x9a6d,0x9a70,0x9a73,0x9a79}) do
     local mark=marks[pc]
     msg=msg..string.format(' %x:%d/%d',pc,mark[2],mark[1]-marks[0x80a7][1])
    end
    print(msg)
   end
  end
 end
end,emu.callbackType.exec,0x9ab2)
emu.addMemoryCallback(function()
 if f>=610 then
  heldFrames=heldFrames+1
  local sl=emu.getState()['ppu.scanline']
  assert(sl>=210 and sl<=212,'Lag frames must retain the native HUD split: '..sl)
 end
end,emu.callbackType.exec,H.BusyHud)
emu.addMemoryCallback(function()
 if f>=610 then updates=updates+1 end
end,emu.callbackType.exec,0x80b3)
emu.addMemoryCallback(function()
 if f>=610 then
  local n=0
  for i=0,5 do
   if r(0x123+i)~=0 then n=n+1 end
   if r(0x7050+i)~=0 then n=n+1 end
  end
  maxShots=math.max(maxShots,n)
 end
end,emu.callbackType.exec,H.EarlyCombat)
emu.addEventCallback(function()
 f=f+1
 if f==480 and stage~=0 then w(0x19,stage);w(0x26,stage);w(0x24,0);w(0x1b,0);w(0x7005,1) end
 if f==600 then
  w(0x7005,1);w(0x44,2);w(0x45,2);w(0x41,1);w(0x40,4)
  w(0x320,88);w(0x360,48);w(0x7041,0)
  for i=0,23 do w(0x7a0+i,48);w(0x7c0+i,88) end
 end
 if f==3000 then
  print('STRESS stage '..stage..' updates '..updates..' splits '..splits..' late '..late..' held '..heldFrames..' ready '..maxReady..' drawcycles '..maxDraw..' maxshots '..maxShots..' contact '..maxContact)
  assert(late==0,'Full projectile load must preserve the background/HUD split')
  assert(maxShots==12,'Stress must reach the full twelve-fireball pool')
  -- endFrame can interrupt one update/held-frame handler in progress.
  assert(math.abs(skipped-heldFrames)<=1 and math.abs(updates+heldFrames-2390)<=1,'Every busy frame must retain the complete playfield and HUD')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
