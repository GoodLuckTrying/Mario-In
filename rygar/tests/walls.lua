-- Controlled native-format terrain, within the first no-scroll viewport.
-- Native player/camera/probe/response code is retained; enemy damage isolated.
local f=0;local began=nil;local minY=255;local released=0;local landed=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=began and f-began or -1
 setPad(0,{start=not began and f>=120 and f%60<2,right=t>=10 and t<100,left=t>=100 and t<200,a=t>=20 and t<45,b=t>=10 and t<200})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
 if not began and r(0x522)&0xA0~=0 then began=f;w(0x512,80);w(0x502,0);w(H.M_X_FRAC,0)end
 if not began then return end
 for col=0,32 do
  for row=0,3 do
   w(0x38a+col*4+row,0)
   w(0x40e+col*4+row,(col<=5 or col>=16)and 255 or(row==3 and 255 or 0))
  end
 end
 local t=f-began;local x=r(0x512);local y=r(0x4f2)
 assert(x>=47 and x<=112,'solid side walls contain the player')
 assert(r(0x17)==0,'room remains within its native no-scroll viewport')
 minY=math.min(minY,y)
 if t>=75 and t<95 and y==162 and r(H.M_STATE)==0 then landed=landed+1 end
 if t>=160 and t<195 and x<100 then released=released+1 end
end,emu.callbackType.exec,0x9b9a)
emu.addEventCallback(function()
 f=f+1
 if began and f-began>=220 then
  assert(minY<125,'jump against a solid wall exercised')
  assert(landed>=15,'wall contact must not repeatedly restart the falling arc')
  assert(released>20,'reverse input releases Mario from the wall')
  print('PASS wall jump lands promptly, both walls contain Mario, reversal escapes');emu.stop(0)
 end
 assert(f<1200,'bounded wall fixture')
end,emu.eventType.endFrame)
