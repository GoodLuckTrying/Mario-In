dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local question=nil
local saved=false
local returned=nil
emu.addMemoryCallback(function()
 if not first or f-first<10 or seeded then return end
 seeded=f
 w(H.Items,2);w(H.InvBombs,5);w(H.Bow,1);w(H.InvArrow,2);w(H.InvRing,1);w(H.InvBoomerang,1)
 w(H.WorldFlags+0x161,0x5a)
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)
 local mode=r(H.GameMode)
 if mode==8 then
  question=question or f
  return{select=f-question==10,start=f-question==20}
 end
 if saved and mode==1 then return{start=f%30==2}end
 return{a=t==5,start=seeded and f-seeded==25}
end
function input2(t)return{up=r(H.MenuState)==8 and not question,a=r(H.MenuState)==8 and not question}end
function tick(t)
 if not seeded then return end
 if r(H.GameMode)==13 then saved=true end
 if saved and r(H.GameMode)==5 and r(H.IsUpdatingMode)==1 then returned=returned or f end
 if returned and f-returned==15 then
  assert(r(H.Items)==2 and r(H.InvBombs)==5 and r(H.Bow)==1 and r(H.InvArrow)==2 and r(H.InvRing)==1 and r(H.InvBoomerang)==1,'native save/reload preserves collected weapons and passive items')
  assert(r(H.WorldFlags+0x161)==0x5a,'native save/reload preserves world flags')
  assert(r(0x7fff)==0xa5,'private projectile state preserves the save-RAM validity marker')
  assert(r(0x7fc0)==0 and r(0x7fc1)==0,'new session starts without old projectiles')
  finish('native controller save command, checksums, profile reload and world flags')
 end
 assert(t<1500,'complete native save and reload: mode '..r(H.GameMode)..' menu '..r(H.MenuState))
end
