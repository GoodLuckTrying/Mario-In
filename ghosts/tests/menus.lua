local f=0
local title=0
local lives=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function save(n)local o=assert(io.open(TEST_ROOT..'/build/menu-'..n..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
emu.addEventCallback(function()setPad(0,{start=f>=180 and f<650 and f%120<3});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local ptr=r(0x29)+256*r(0x2a)
 local frame=r(ptr+1)
 if frame==0x1b or frame==0x1d then
  assert(r(H.M_ART_POSE)==23,'title/loading icon uses complete Small Mario')
  if r(0x29)==r(H.M_MENU_CMD) then lives=lives+1 else title=title+1 end
  local ppu=r(H.BodyTiles+r(H.M_ACTIVE))*16
  for i=0,127 do assert(emu.read(ppu+i,emu.memType.nesPpuDebug)==r(0x7000+23*128+i),'menu CHR is refreshed after native scene load')end
 end
end,emu.callbackType.exec,H.DrawMario)
emu.addEventCallback(function()
 f=f+1
 if f==170 then save('title')end
 if lives==15 then save('lives')end
 if f==1200 then
  assert(title>20 and lives>20,'native selector and separate interstitial actor both draw Mario')
  print('PASS title selector and interstitial Mario icons, refreshed complete CHR after native loads; '..title..' title and '..lives..' loading draws');emu.stop(0)
 end
end,emu.eventType.endFrame)
