-- Isolated native damage and candle integration, before native actor AI runs.
local frame=0
local case=nil
local actor=8
local before=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local misses={[0]=true,[4]=true,[5]=true,[6]=true,[9]=true,[13]=true}
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 or frame>1150 or (frame-700)%30~=0 then return end
 case=math.floor((frame-700)/30)
 for x=3,27 do
  w(0x434+x,0);w(0x60a0+x,0)
  for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530}) do w(base+x,0) end
 end
 local big=case==1 or case==4 or case==8 or case==9 or case==11 or case==12
 w(0x6001,big and (case==8 or case==12) and 2 or big and 1 or 0)
 w(0x600d,0);w(0x5b,0);w(0x45,64);w(0x46c,0);w(0x3f,176);w(0x354,176);w(0x38c,128);w(0x40,128);w(0x41,0);w(0x450,0)
 w(0x6020,0);w(0x6021,0);w(0x603e,13);w(0x6039,0)
 w(0x434+actor,1);w(0x38c+actor,148);w(0x354+actor,big and 172 or 184)
 w(0x1a8,0);w(0x1a9,64);w(0x7a,0)
 before=r(0x603f)
 if case==0 or case==1 then w(0x38c+actor,173)
 elseif case==3 then w(0x450,1);w(0x38c+actor,108)
 elseif case==4 then w(0x38c+actor,108)
 elseif case==5 then w(0x434+actor,0x2f);w(0x584+actor,0)
 elseif case==6 then w(0x434+actor,4);w(0x60a0+actor,3);w(0x60c0+actor,100)
 elseif case>=7 and case<=9 then
  w(0x434+actor,0x18);w(0x38c+actor,158)
  if case==9 then w(0x488+actor,128);w(0x568+actor,8) end
 elseif case>=10 and case<=12 then
  w(0x434+actor,0x28);w(0x4dc+actor,6);w(0x196,0)
  w(0x6080+actor,1);w(0x60e0+actor,r(0x354+actor));w(0x6100+actor,6);w(0x6120+actor,r(0x46))
  w(0x584+actor,case==12 and 9 or 0)
 elseif case==13 then w(0x603e,14)
 elseif case==14 then w(0x46c,4)
 elseif case==15 then
  w(0x434+9,1);w(0x38c+9,158);w(0x354+9,184)
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if case==nil then return end
 local n=case
 case=nil
 local count=misses[n] and 0 or n==15 and 2 or 1
 assert(r(0x603f)==before+count,'Whip range/direction/contact case '..n)
 assert(r(0x45)==64,'Whip attack must not damage Mario')
 if n==7 then assert(r(0x1a9)==61,'Small whip must use native short-whip damage')
 elseif n==8 then assert(r(0x1a9)==60,'Grown whip must use native long-whip damage')
 elseif n==9 then assert(r(0x1a9)==64,'Whip must respect boss hurt cooldown')
 elseif n==10 or n==11 then
  assert(r(0x196)==0xf0 and r(0x60a0+actor)==n-9,'Whipped candles must persist and drop the correct Mario upgrade')
 elseif n==12 then assert(r(0x196)==0xf0 and r(0x60a0+actor)==0 and r(0x584+actor)==9,'Whip must preserve native subweapon drops') end
 print('Whip combat case '..n..' passed')
 -- Keep the damage fixture separate from uninitialized native AI.
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 w(0x603e,0);w(0x6039,0);w(0x46c,0)
 if n==15 then emu.stop(0) end
end,emu.callbackType.exec,0xe8f0)
emu.addEventCallback(function() frame=frame+1;if frame==1200 then print('FAIL missing whip fixture');emu.stop(1) end end,emu.eventType.endFrame)
