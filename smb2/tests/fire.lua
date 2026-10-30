dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local shots=0
local hits=0
local defeats=0
local bounced=false
local lastvy={}
local countmax=0
local floor=nil
emu.addMemoryCallback(function()if seeded then shots=shots+1 end end,emu.callbackType.exec,H.MarioFireSpawn_Create)
emu.addMemoryCallback(function()if seeded then hits=hits+1 end end,emu.callbackType.exec,H.MarioFireHit)
emu.addMemoryCallback(function()if seeded then defeats=defeats+1 end end,emu.callbackType.exec,H.EnemyKnockout)
emu.addMemoryCallback(function()
 if not first or f-first<130 or seeded then return end
 seeded=f
 for i=0,8 do w(H.EnemyState+i,0);w(0x7e40+i,0)end
 w(H.PlayerHealth,0x1f);w(H.PlayerCurrentSize,0);w(H.DamageInvulnTime,0)
 -- Widen the native ledge into a deterministic collision fixture. Keep
 -- the native tile handler and the full fireball movement/collision path.
 if MODE~='hit' then
  local row=(r(H.PlayerYLo)+32)&0xf0
  floor=row+256*r(H.PlayerYHi)
  local page=r(H.PlayerYHi)*0xf0
  for a=0,2399 do w(0x6000+a,0x40)end
  for x=0,15 do w(0x6000+page+row+x,0xd5)end
  w(H.PlayerYLo,row-32);w(H.PlayerYVelocity,0);w(H.PlayerYAcceleration,0);w(H.PlayerInAir,0)
 end
 if MODE=='hit' then
  w(H.EnemyState,1);w(H.ObjectType,1);w(H.ObjectXLo,(r(H.PlayerXLo)+55)&255);w(H.ObjectXHi,r(H.PlayerXHi));w(H.ObjectYLo,(r(H.PlayerYLo)+12)&255);w(H.ObjectYHi,r(H.PlayerYHi))
  w(H.ObjectXVelocity,0);w(H.ObjectYVelocity,0);w(H.EnemyRawDataOffset,255);w(H.EnemyHP,0);w(H.ObjectHitbox,2);w(H.EnemyArray_492,5);w(H.EnemyArray_46E,0)
 end
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)
 if not seeded then return{}end
 local dt=f-seeded
 return{b=dt==2 or dt==5 or dt==8}
end
function tick(t)
 if not seeded then return end
 local count=0
 for i=0,8 do
  if r(0x7e40+i)>0 then
   count=count+1
   local vy=r(H.ObjectYVelocity+i)
   if lastvy[i]and lastvy[i]<128 and vy>=128 then
    bounced=true
    assert(r(H.ObjectYLo+i)+256*r(H.ObjectYHi+i)+8==floor,'the visible eight-pixel fireball touches the floor at its bounce: '..(r(H.ObjectYLo+i)+256*r(H.ObjectYHi+i)+8)..' versus '..tostring(floor))
   end
   lastvy[i]=vy
  end
 end
 countmax=math.max(countmax,count)
 assert(count<=2,'each brother can have at most two fireballs')
 assert(r(H.PlayerHealth)==0x1f,'friendly fireballs never hurt their owner')
 if f-seeded==100 then
  assert(shots>=2 and countmax==2,'two fresh B presses create independent fireballs')
  if MODE=='hit' then assert(hits>0 and defeats>0,'fireball hits and defeats a real enemy through native thrown-object damage')
  else assert(bounced,'fireball bounces from actual native terrain')end
  screenshot('fire-'..(MODE or 'bounce')..'-'..(CHAR or 0));finish('two-shot limit, friendly collision and '..(MODE or 'terrain bounce'))
 end
end
