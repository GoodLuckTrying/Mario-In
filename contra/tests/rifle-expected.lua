-- Source-sheet grip locations and native Contra aim semantics.
local gx={3,4,3,3,3,4,4,4,4,4,3,4,7,6,6,8,8,10,10,10,10,10,0,7,3,0,8}
local gy={15,17,16,10,16,15,15,15,15,15,22,17,24,23,23,23,24,22,22,22,22,22,0,23,15,0,24}
local modes={3,1,0,2,0,0,2,0,1,3,4,4}
return function(raw,aim,air,bx,by,attr)
 local pose=raw&63;local recoil=(raw&64)~=0
 local style=(pose<12 or pose==24)and 0 or pose>=17 and pose<=21 and 4 or 2
 if recoil then style=style+1 end
 local dx=gx[pose+1]-(recoil and 1 or 0);local dy=gy[pose+1]
 local mode=modes[aim+1]
 if(aim==4 or aim==5)and air then mode=4 end
 local tile=0x68+style*4;local second=tile+2
 if mode~=0 then
  dy=dy+({-6,-5,-7,-4})[mode]
  if mode<3 then
   dx=dx-(style>=2 and 3 or 0)
   tile=({0x42,0x46,0x4a,0x4e,0x80,0x84})[style+1];second=tile+2
  else
   dx=dx+(style<2 and 9 or 3)
   tile=0x88+math.floor(style/2)*2;second=0x8e
  end
 end
 local flip=(attr&64)~=0
 local x=(bx+(flip and -dx or dx))&255
 local y=(by+dy)&255
 local flags=(attr&0x60)|3|((mode==2 or mode==4)and 0x80 or 0)
 return {x=x,y=y,tile=tile,second=second,attr=flags,x2=(x+(flip and -8 or 8))&255,mode=mode}
end
