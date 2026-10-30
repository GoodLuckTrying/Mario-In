dofile(TEST_ROOT..'/tests/common.lua')
local seeded=false
local heads={}
local feet={down={},up={}}
local changes={}
local lastFlip={}
local lastChange={}
local idle={}
local records={}
local positions={down={},up={}}
local expected=dofile(TEST_ROOT..'/build/directional-walk-fixtures.lua')
local function pixels()
 local out={}
 local sprite=emu.memType.nesSpriteRam
 for y=0,15 do
  local row={}
  for half=0,1 do
   local tile=emu.read(73+half*4,sprite)
   local attr=emu.read(74+half*4,sprite)
   local a=(tile+(y//8))*16+y%8
   local lo=emu.read(a,emu.memType.nesPpuDebug);local hi=emu.read(a+8,emu.memType.nesPpuDebug)
   for x=0,7 do
    local shift=(attr&0x40)==0 and 7-x or x
    row[#row+1]=tostring(((lo>>shift)&1)|(((hi>>shift)&1)<<1))
   end
  end
  out[#out+1]=table.concat(row)
 end
 return out
end
emu.addMemoryCallback(function()
 if not first or seeded then return end
 seeded=true
 for i=1,12 do w(H.ObjType+i,0);w(H.ObjMetastate+i,0)end
 for i=0,703 do w(0x6530+i,0x26)end
 w(H.ObjX,120);w(H.ObjY,141);w(H.ObjState,0);w(H.ObjGridOffset,0);w(H.DoorwayDir,0)
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)return{down=t<30,up=t>=40 and t<70}end
function tick(t)
 if t<3 then return end
 local moving=t<28 and 'down' or t>=43 and t<68 and 'up' or nil
 local standing=t>=33 and t<39 and 'down' or t>=73 and t<79 and 'up' or nil
 local p=pixels()
 local sprite=emu.memType.nesSpriteRam
 if moving then
  local flip=(emu.read(74,sprite)>>6)&1
  local head=table.concat(p,'',1,7)
  heads[moving]=heads[moving]or head
  assert(heads[moving]==head,'vertical stepping keeps the cap and face steady')
  local lower=table.concat(p,'',13,16)
  feet[moving][flip]=feet[moving][flip]or lower
  assert(feet[moving][flip]==lower,'each step has a stable foot silhouette')
  local left,right=-1,-1
  for y=12,15 do
   for x=2,7 do if p[y+1]:sub(x+1,x+1)~='0' then left=y end end
   for x=8,13 do if p[y+1]:sub(x+1,x+1)~='0' then right=y end end
  end
  assert(table.concat(p)==table.concat(expected[moving][flip]),'the supplied walking frame must reach hardware exactly, with the correct alternating feet')
  if lastFlip[moving]~=nil and lastFlip[moving]~=flip then
   if lastChange[moving]then assert(t-lastChange[moving]==6,'feet alternate every six moving frames')end
   lastChange[moving]=t;changes[moving]=(changes[moving]or 0)+1
  end
  lastFlip[moving]=flip
  positions[moving][r(H.ObjY)]=true
  if not LEVEL and t%2==0 and(t<28 or t>=44 and t<68)then
   local name='walk-'..moving..'-'..t
   screenshot(name)
   records[#records+1]=string.format('{"name":"%s","direction":"%s","x":%d,"y":%d}',name,moving,emu.read(75,sprite),emu.read(72,sprite)+1)
  end
 end
 if standing then
  local tile=emu.read(73,sprite)
  assert(standing=='down'and(tile==8 or tile==10)or standing=='up'and(tile==12 or tile==14),'stopping returns to the reference standing pose')
  local full=table.concat(p)
  idle[standing]=idle[standing]or full
  assert(idle[standing]==full,'standing freezes the feet')
 end
 if t==80 then
  for _,direction in ipairs({'up','down'})do
   assert(feet[direction][0]and feet[direction][1]and feet[direction][0]~=feet[direction][1],'both real foot poses reach hardware OAM')
   assert((changes[direction]or 0)>=3,'vertical movement cycles repeatedly')
   local count=0;for _,_ in pairs(positions[direction])do count=count+1 end
   assert(count>10,'Mario travels while the gait animates')
  end
  if not LEVEL then
   local out=assert(io.open(TEST_ROOT..'/build/walk-captures.json','w'));out:write('['..table.concat(records,',')..']');out:close()
  end
  finish('actual up/down movement, alternating raised feet, steady head, six-frame steps and standing recovery')
 end
end
