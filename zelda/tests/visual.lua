dofile(TEST_ROOT..'/tests/common.lua')
local poses={}
local prefix=OLD and 'previous-' or 'visual-'
local seeded=false
local captures={[25]='front',[55]='back',[85]='left',[115]='right',[145]='front-attack',[175]='back-attack',[205]='lift-one-hand',[235]='lift-two-hands'}
emu.addMemoryCallback(function()
 if not first or seeded then return end
 seeded=true
 for i=1,12 do w(H.ObjType+i,0);w(H.ObjMetastate+i,0)end
 for i=0,703 do w(0x6530+i,0x26)end
 w(H.ObjX,120);w(H.ObjY,141);w(H.ObjState,0);w(H.ObjGridOffset,0);w(H.DoorwayDir,0)
end,emu.callbackType.exec,H.UpdatePlayer)
emu.addMemoryCallback(function()
 if not first then return end
 local t=f-first
 if t==140 or t==170 then
  w(H.Items,1);w(H.ObjState,0);w(H.ObjAnimCounter,6)
 end
 if t==200 or t==230 then
  w(H.ObjState,0x40);w(H.ItemLiftTimer,120);w(H.ItemTypeToLift,t==200 and 1 or 14)
 end
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)
 if t<20 then return{down=true}
 elseif t>=30 and t<50 then return{up=true}
 elseif t>=60 and t<80 then return{left=true}
 elseif t>=90 and t<110 then return{right=true}
 elseif t>=120 and t<140 then return{down=true}
 elseif t>=150 and t<170 then return{up=true}end
 return{a=t==141 or t==171}
end
function tick(t)
 local name=captures[t]
 if name then
  local sprite=emu.memType.nesSpriteRam
  local x=emu.read(75,sprite);local y=emu.read(72,sprite)+1
  assert(y<240,'Mario is visible in every directional/action pose')
  screenshot(prefix..name)
  poses[#poses+1]=string.format('{"name":"%s","x":%d,"y":%d}',name,x,y)
 end
 if t==240 then
  local out=assert(io.open(TEST_ROOT..'/build/'..prefix..'poses.json','w'));out:write('['..table.concat(poses,',')..']');out:close()
  finish('in-game front, back, side, attack and item-lift screenshots for visual inspection')
 end
end
