-- Read-only controller routing: upgrades with the whip, then an indoor heart.
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local roomStartingPickups=nil
return function(frame)
 local input={start=frame==120}
 if frame<710 or r(0x6000)~=0x4d or r(0x18)~=5 then return input end
 local stage=r(0x28)
 if stage==1 and not roomStartingPickups then roomStartingPickups=r(0x6047) end
 if stage>1 or (stage==1 and r(0x6047)>roomStartingPickups) then return nil end
 if stage==0 and r(0x6001)==2 then input.right=true;input.b=true;return input end
 local target=nil
 local distance=1000
 local pickup=false
 for x=3,22 do
  if r(0x60a0+x)>0 and r(0x300+x)==0 then
   local d=math.abs(r(0x38c+x)-r(0x38c))
   if d<distance then target=r(0x38c+x);distance=d;pickup=true end
  end
 end
 if not pickup then
  for x=3,22 do
   local ai=r(0x434+x)
   if ai>=0x28 and ai<0x2f and r(0x300+x)==0 then
    local d=math.abs(r(0x38c+x)-r(0x38c))
    if d<distance then target=r(0x38c+x);distance=d end
   end
  end
 end
 if target then
  local dx=target-r(0x38c)
  input.right=dx>3;input.left=dx< -3
  input.b=not pickup and frame%30==0
 else input.right=true;input.b=frame%30==0 end
 return input
end
