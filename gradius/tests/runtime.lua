local f=0
local updates=0
local zero=0
local mario=0
local split=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f>=200 and f<210,right=f>=480 and f<500,left=f>=520 and f<540,up=(f>=320 and f<455) or (f>=600 and f<650)})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=450 and f<750 then updates=updates+1 end
end,emu.callbackType.exec,0x80b3)
emu.addMemoryCallback(function()
 if f<450 or r(0x100)~=1 then return end
 for i=0,3 do assert(r(0x7100+i)==r(0x200+i),'Sprite zero must preserve the native HUD timing marker') end
 zero=zero+1
 local tiles={9,11,13,223}
 for i=0,3 do assert(r(0x7105+i*4)==tiles[i+1],'All four Mario body sprites must be present') end
 mario=mario+1
end,emu.callbackType.exec,0x80aa)
emu.addMemoryCallback(function()
 if f>=450 then
  local sl=emu.getState()['ppu.scanline']
  assert(sl>=210 and sl<=212,'HUD scroll split must remain on the native boundary: '..sl)
  split=split+1
 end
end,emu.callbackType.exec,0x9ab2)
local coords={}
emu.addEventCallback(function()
 f=f+1
 if f==430 then
  assert(r(0)==5 and r(0x100)==1,'Cold boot must enter native gameplay')
  local code=assert(io.open(TEST_ROOT..'/build/hack.bin','rb')):read('*a')
  for i=1,#code do assert(r(0x5fff+i)==code:byte(i),'CHR bootstrap must load exact executable RAM bytes') end
 end
 if f==480 or f==500 or f==520 or f==540 or f==560 or f==580 or f==600 or f==620 then coords[f]={r(0x360),r(0x320)} end
 if f==650 then
  assert(coords[500][1]>coords[480][1] and coords[540][1]<coords[520][1],'D-pad must fly both horizontal directions')
  assert(coords[500][2]>coords[480][2] and coords[620][2]<coords[600][2],'Release must fall under gravity; holding Up must provide lift')
  local out=assert(io.open(TEST_ROOT..'/build/mario-gameplay.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==750 then
  assert(updates>=298 and mario>280 and zero>280 and split>280,'Gameplay must complete at the native 60 fps rate')
  print('PASS cold boot, gravity/lift, horizontal flight, complete Mario, HUD split, '..updates..'/300 updates');emu.stop(0)
 end
end,emu.eventType.endFrame)
