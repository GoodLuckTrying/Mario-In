local f=0
local vertical=VERTICAL or false
local moved=0
local bad=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 local a=vertical and f>=970 and f%90<25
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180,right=f>=950,b=f>=950,a=a})
 setPad(1,{right=f>=950,b=f>=950,a=a})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for a=0x680,0x6FF do w(a,0x55) end
 for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end
 for p=0,1 do
  w(0x6004+p*128,2);w(0x6035+p*128,0);w(0x604C+p*128,2)
  w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,200)
  if f<945 then w(N.SPRITE_X_POS+p,128);w(N.SPRITE_Y_POS+p,132);w(0x6005+p*128,0);w(0x6018+p*128,0) end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f<950 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then bad=bad+1 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==480 and vertical then w(N.CURRENT_LEVEL,2);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f>=950 then
  moved=moved+r(N.FRAME_SCROLL)
  assert(r(N.FRAME_SCROLL)<=(vertical and 5 or 3),'Two players must not double the camera scroll speed')
  assert(r(N.SPRITE_X_POS)<=230 and r(N.SPRITE_X_POS+1)<=230,'Running must respect camera bounds')
 end
 if f==1450 then
  print('Camera vertical='..tostring(vertical)..' moved='..moved..' bad VRAM writes='..bad..' x='..r(N.SPRITE_X_POS)..'/'..r(N.SPRITE_X_POS+1))
  assert(moved>(vertical and 100 or 500),'Running/jumping must scroll through native stage data')
  assert(bad==0,'Pose and terrain streaming must stay within vblank while scrolling')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
