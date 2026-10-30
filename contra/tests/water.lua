local f=0
local low=255
local high=0
local strokes=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 local a=f>=960 and f%60<15
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180,right=f>=950,a=a})
 setPad(1,{right=f>=950,a=a})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for a=0x680,0x6FF do w(a,0xAA) end
 for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end
 for p=0,1 do
  w(0x6004+p*128,POWER or 1);w(0x604C+p*128,2);w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,200)
  if f<945 then w(N.SPRITE_Y_POS+p,200);w(0x6005+p*128,2);w(0x6018+p*128,1) end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f>950 then
  for p=0,1 do
   local y=r(N.SPRITE_Y_POS+p);low=math.min(low,y);high=math.max(high,y)
   if r(0x6018+p*128)>=128 then strokes=strokes+1 end
   assert(r(N.PLAYER_STATE+p)==1,'Water must support both characters without drowning at the bottom')
  end
 end
 if f==1300 then
  print('Water y='..low..'..'..high..' stroke frames='..strokes)
  assert(low<180 and high<=208 and strokes>50,'A presses must produce swimming strokes')
  assert(r(0x6047)==1 and r(0x60C7)==1,'Both players must retain their own swimming state')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
