dofile(TEST_ROOT..'/tests/common.lua')
local updates=0;local last=nil;local gap=0;local hits=0;local births=0;local pose={};local xs={}
local prepared=false;local oldhp=nil;local oldttl={0,0,0,0}
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if r(0xc)~=0 then return end
 if not first then return end
 updates=updates+1;if last then gap=math.max(gap,f-last)end;last=f
end,emu.callbackType.exec,H.UpdateBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=4 then return end

 if not first then return end
 local x=emu.getState()['cpu.x'];local owner=r(0x4c8+x);local ttl=r(0x4b0+x)
 if ttl>0 then hits=hits+1 end
end,emu.callbackType.exec,H.FireHit)
function input(t)
 if t<80 then return{right=true}
 elseif t<115 then return{down=true}
 elseif t<150 then return{up=true}
 elseif t<180 then return{left=true}
 elseif t<205 then return{a=t%16==0}
 elseif t<500 then return{b=t%18==0}
 elseif t==510 or t==535 then return{start=true}
 elseif t<800 then return{left=t%160<80,right=t%160>=80,b=t%20==0,a=t%31==0}end
 return{}
end
function tick(t)
 if t<0 then return end
 if not prepared then prepared=true;assert(r(0x2a)==(CHOICES or{0})[1]and r(0x2b)==(CHOICES or{0,1})[2],'selected Mario/Luigi identities survive the versus screen')end
 pose[r(0x4d9)]=true;xs[r(0x2d)]=true
 for i=0,3 do local v=r(0x4b0+i);if oldttl[i+1]==0 and v>0 then births=births+1 end;oldttl[i+1]=v end
 if t==30 then screen('match-standing')end
 if t==95 then screen('match-front')end
 if t==135 then screen('match-back')end
 if t>=180 and t<500 then
  -- A native stationary opponent fixture allows deterministic actual
  -- controller kick/punch poses and fireball hits. Start it before the
  -- first A press so a live AI grab cannot replace the expected kick.
  w(0x2d,80);w(0x2c,148);w(0x2e,180);w(0x2f,180);w(0x3b,0);w(0x3a,1)
  w(0x3c,0);w(0x3d,0);w(0x3e,0);w(0x3f,0)
  if t==205 then w(0x79,200);w(0x7a,200)end
 end
 if t==420 then screen('match-fireballs')end
 if t==500 then assert(r(0x7a)<150,'physical B fireballs lower the opponent energy bar');assert(r(0x79)==200,'own energy is unchanged by firing');assert(births>=8,'repeated physical B fires permanent shots');assert(pose[4]and pose[5],'native melee uses both reused Kung Fu attack poses')end
 if t==850 then
  local n=0;for _ in pairs(xs)do n=n+1 end
  assert(n>20,'controller movement in the ring');assert(pose[12]and pose[13]and pose[15]and pose[16],'front and back feet both animate')
  assert(gap<=2 and updates>700,'active loop remains responsive across attacks and pause')
  finish('cold boot, both roster identities, controller walking/front/back/melee/fireballs, native energy damage, pause and resumed play')
 end
end
