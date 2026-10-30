local f=0
local p=PLAYER or 0
local checked={0,0,0}
local shots={0,0}
local expected={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
emu.addEventCallback(function()
 for q=0,1 do
  setPad(q,{start=q==0 and f>=200 and f<210,b=q==p and ((f>=510 and f<513) or (f>=710 and f<713)),a=q==p and f>=540,up=q==p and f>=500 and r(0x320)>76,right=q==p and f>=750 and f<790,left=q==p and f>=830 and f<870})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 expected={}
 if f>=500 and r(0x100)==1 then
  for owner=0,2 do
   if r(0x120+owner)~=0 then expected[#expected+1]={r(0x360+owner),r(0x320+owner)} end
  end
 end
end,emu.callbackType.exec,0x80a7)
emu.addMemoryCallback(function()
 if #expected==0 then return end
 local tiles={9,11,13,223}
 local offset=4
 for _,xy in ipairs(expected) do
  for i=0,3 do
   local at=0x7100+offset+i*4
   assert(r(at)==xy[2]-9+(i>=2 and 16 or 0),'Each Option must use its native following Y position')
   assert(r(at+1)==tiles[i+1] and r(at+2)==(p==0 and 3 or 0),'Each Option must be a complete four-sprite copy of the current brother')
   assert(r(at+3)==xy[1]-4+(i%2)*8,'Each Option must use its native following X position')
  end
  offset=offset+16
 end
 checked[#expected]=checked[#expected]+1
end,emu.callbackType.exec,0x80aa)
emu.addMemoryCallback(function()
 if f>=720 then
  for owner=1,2 do
   if r(0x123+owner)~=0 or r(0x126+owner)~=0 then shots[owner]=shots[owner]+1 end
  end
 end
end,emu.callbackType.exec,H.EarlyCombat)
emu.addEventCallback(function()
 f=f+1
 if f==500 then
  if p==1 then w(3,0x70);w(0xa,3) end
  w(0x18,p);w(0x7005,1);w(0x320,76);w(0x360,120);w(0x7041,0)
  for i=0,23 do w(0x7a0+i,120);w(0x7c0+i,76) end
 end
 if f==500 or f==700 then w(0x42,5) end
 if f==530 then assert(r(0x45)==1,'Native B power-up selection must acquire the first Option') end
 if f==730 then assert(r(0x45)==2,'Native B power-up selection must acquire the second Option') end
 if f==800 then
  local out=assert(io.open(TEST_ROOT..'/build/mario-options-'..p..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==900 then
  assert(checked[1]>5 and checked[2]>100 and checked[3]>100,'One, two and three complete Marios must all be verified')
  assert(shots[1]>50 and shots[2]>50,'Both Mario Options must continue firing through native mechanics')
  print('PASS Mario Option pickup, complete art, native following and firing, controller '..p)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
