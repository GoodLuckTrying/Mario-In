CHOICES={HUMAN or 0,OPPONENT or 0}
dofile(TEST_ROOT..'/tests/common.lua')
function input(t)
 return{left=t%440<180,right=t%440>=220 and t%440<400,up=t%300<75,down=t%300>=150 and t%300<225,b=t%18==1,a=t%29==3}
end
function tick(t)
 if t<0 then return end
 if t==400 or t==800 then screen('combat-raster-'..(OPPONENT or 0)..'-'..t)end
 if t==1000 then
  assert(WWF_RASTER_FRAMES>=990,'continuous active combat keeps the HUD split for every frame')
  finish('unfrozen original opponent '..(OPPONENT or 0)..', movement, native attacks and fireballs retain exact HUD/ring raster phases and CPU body/shadow OAM')
 end
end
