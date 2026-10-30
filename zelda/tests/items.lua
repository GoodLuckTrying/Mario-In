dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local used=0
local sword=0
local fire=false
local native=false
local methods={[0]='WieldBoomerang',[1]='WieldBomb',[2]='WieldArrow',[4]='WieldCandle',[5]='WieldFlute',[6]='WieldFood',[7]='WieldPotion',[8]='WieldRod'}
local slot=ITEM or 0
emu.addMemoryCallback(function()if seeded and r(H.GameMode)==5 then used=used+1 end end,emu.callbackType.exec,H[methods[slot]])
emu.addMemoryCallback(function()if seeded and r(H.GameMode)==5 then sword=sword+1 end end,emu.callbackType.exec,H.WieldSword)
emu.addMemoryCallback(function()
 if not first or f-first<10 or seeded then return end
 seeded=f
 for i=1,12 do w(H.ObjType+i,0);w(H.ObjMetastate+i,0)end
 for i=0,703 do w(0x6530+i,0x26)end
 w(H.Items,1);w(H.InvBoomerang,1);w(H.InvBombs,8);w(H.InvArrow,1);w(H.Bow,1)
 w(H.InvCandle,2);w(H.Items+5,1);w(H.InvFood,1);w(H.Potion,2);w(H.Items+8,1);w(H.InvRupees,99)
 w(H.SelectedItemSlot,slot)
 w(H.ObjX,120);w(H.ObjY,141);w(H.ObjDir,1);w(H.ObjState,0);w(H.ObjGridOffset,0)
 w(H.HeartValues,0x20);w(H.HeartPartial,128)
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return{a=dt==5,b=dt==5}
end
function tick(t)
 if not seeded then return end
 fire=fire or r(0x7fc0)>0 or r(0x7fc1)>0
 if slot==0 then native=native or r(H.ObjState+15)>0
 elseif slot==1 then native=native or r(H.InvBombs)==7 and r(H.ObjState+16)>0
 elseif slot==2 then native=native or r(H.ObjState+18)>0 and (r(H.RupeesToSubtract)>0 or r(H.InvRupees)<99)
 elseif slot==4 then native=native or r(H.ObjState+16)>0 or r(H.ObjState+17)>0
 elseif slot==5 then native=native or r(H.FluteTimer)>0
 elseif slot==6 then native=native or r(H.ObjState+15)>=128
 elseif slot==7 then native=native or r(H.Potion)==1 and r(H.World_IsFillingHearts)>0
 elseif slot==8 then native=native or r(H.ObjState+18)>=0x30 end
 if f-seeded==100 then
  assert(used>=1 and native,'B uses the collected '..methods[slot]..' through its native handler')
  assert(fire and sword>0,'A adds a fireball while retaining the collected sword')
  assert(r(H.GameMode)==5,'item usage does not corrupt the room or mode')
  finish('native '..methods[slot]..', collected sword and independent A fireball coexist')
 end
end
