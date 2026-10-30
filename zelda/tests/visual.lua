dofile(TEST_ROOT..'/tests/common.lua')
local poses={}
local lifts=dofile(TEST_ROOT..'/build/lift-fixtures.lua')
local liftFrames=0
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
  w(H.ObjState,0x40);w(H.ItemLiftTimer,120);w(H.ItemTypeToLift,t==200 and 1 or 12)
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
 local oam=emu.memType.nesSpriteRam
 if t>=201 and emu.read(73,oam)==0x78 then
  local right=emu.read(77,oam)
  assert(right==0x0a or right==0x56,'a lift uses a full Mario right half, never a mirrored left face')
  local art=lifts[right==0x0a and 1 or 2]
  for half=0,1 do
   local at=72+half*4;local tile=emu.read(at+1,oam);local attr=emu.read(at+2,oam)
   assert(emu.read(at,oam)<240 and attr&0xc0==0,'item lift keeps two upright unmirrored Mario halves: frame '..t..' half '..half..' tile '..tile..' attr '..attr..' y '..emu.read(at,oam))
   for y=0,15 do
    local a=(tile+y//8)*16+y%8
    local lo=emu.read(a,emu.memType.nesPpuDebug);local hi=emu.read(a+8,emu.memType.nesPpuDebug)
    for x=0,7 do
     local pixel=((lo>>(7-x))&1)|(((hi>>(7-x))&1)<<1)
     assert(pixel==tonumber(art[y+1]:sub(half*8+x+1,half*8+x+1)),'complete asymmetric Mario lift pixels, frame '..t..' half '..half)
    end
   end
  end
  liftFrames=liftFrames+1
 end
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
  assert(liftFrames>=37,'every one/two-hand lift frame is checked in hardware')
  finish('in-game front, back, side, attack and item-lift screenshots for visual inspection')
 end
end
