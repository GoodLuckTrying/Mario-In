dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local loaded=0
local entered=0
local oldarea=nil
emu.addMemoryCallback(function()if seeded then loaded=loaded+1 end end,emu.callbackType.exec,H.StartLevel)
emu.addMemoryCallback(function()if seeded then entered=entered+1 end end,emu.callbackType.exec,H.DoorHandling_GoThroughDoor)
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 local doors={}
 for i=0,3 do doors[r(H.DoorTiles+i)]=true end
 local index=nil
 for i=0,959 do if doors[r(0x6000+i)]then index=i end end
 assert(index,'the native opening area contains a doorway')
 seeded=f;oldarea=r(H.CurrentLevelArea)
 local x=index%16*16
 local y=(index//16)*16-16
 local camera=math.max(0,y-160)
 w(H.ScreenYLo,camera%256);w(H.ScreenYHi,camera//256);w(H.NeedsScroll,0);w(H.VerticalScrollDirection,0)
 w(H.PlayerXLo,x);w(H.PlayerXHi,0);w(H.PlayerYLo,y%256);w(H.PlayerYHi,y//256)
 w(H.PlayerXVelocity,0);w(H.PlayerYVelocity,0);w(H.PlayerInAir,0);w(H.PlayerState,0);w(H.PlayerLock,0);w(H.DamageInvulnTime,0)
 w(H.PlayerCurrentSize,SMALL and 1 or 0);w(H.PlayerHealth,SMALL and 15 or 31)
 AREA=nil
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)return{up=seeded and (f-seeded)%12<5}end
function tick(t)
 if not seeded then return end
 if loaded>0 and r(H.CurrentLevelArea)~=oldarea and f-seeded>80 then
  assert(entered>0,'Up invokes the native doorway trigger')
  assert(r(H.PlayerHealth)==(SMALL and 15 or 31),'door transition preserves health and form')
  screenshot('door-'..(CHAR or 0)..'-'..tostring(SMALL));finish('native opening door, room loader and preserved Mario/Luigi form')
 end
 assert(f-seeded<600,'door transition completes: trigger '..entered..' loaded '..loaded..' old '..oldarea..' new '..r(H.CurrentLevelArea)..' x '..r(H.PlayerXLo)..' y '..r(H.PlayerYLo))
end
