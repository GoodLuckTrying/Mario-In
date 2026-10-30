dofile(TEST_ROOT..'/tests/common.lua')
local saved=nil
local live=false
local checked=false
local inventory=false
local function state()
 local v={r(H.ObjX),r(H.ObjY)}
 for i=0,11 do v[#v+1]=r(0x7fc0+i)end
 return table.concat(v,',')
end
function input(t)
 return{a=t==5 or t>=20 and t<=40,b=t>=20 and t<=40,right=t>=20 and t<=40,select=t==12 or t==55,start=t==85 or t==185}
end
function tick(t)
 if t==10 then live=r(0x7fc0)>0 or r(0x7fc1)>0 end
 if t==18 then assert(r(H.Paused)==1,'Select pauses native play');saved=state()end
 if t==45 then assert(state()==saved,'pause freezes player, fireball coordinates, speed phase and lifetime');checked=true end
 if t>110 and t<180 and r(H.MenuState)>0 then inventory=true end
 if t==260 then
  assert(live and checked and inventory,'projectile, pause and scrolling inventory were exercised')
  assert(r(H.MenuState)==0 and r(H.Paused)==0,'inventory closes and play resumes')
  finish('native Select pause and Start inventory preserve/fireball state and resume correctly')
 end
end
