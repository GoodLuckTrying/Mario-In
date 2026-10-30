-- Long fall while native horizontal scrolling competes with vertical following.
-- Clear the collision cache until seven+ vertical strips load, then add a floor.
local f=0;local began=nil;local oldCamera=0;local descent=0;local landed=0;local floor=false;local updates=0;local horizontal=0;local vertical=0;local support=nil
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f>=120 and f<180 and f%60<2,right=began~=nil and MOVE~=false,b=began~=nil and MOVE~=false})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()w(0x43,7)end,emu.callbackType.exec,0xd19b)
emu.addMemoryCallback(function()
 if f<400 or r(0x10)~=11 then return end
 for i=0,5 do w(0x650+i*16,0)end
 if not began then
  began=f;oldCamera=r(0x0d)
  w(0xc4,0);w(0xc5,0);w(0x63,MOVE==false and 80 or 128);w(0x64,72);w(0x62,0x48)
  w(H.M_STATE,2);w(H.M_VY,4);w(H.M_VY_FRAC,0);w(H.M_Y_FRAC,0)
  w(H.M_SMB_X_SPEED,MOVE==false and 0 or 40);w(H.M_SMB_X_ABS,MOVE==false and 0 or 40)
 end
 local delta=r(0x0d)-oldCamera
 if delta>120 then delta=delta-240 elseif delta< -120 then delta=delta+240 end
 descent=descent+delta;oldCamera=r(0x0d);updates=updates+1
 if r(0xc4)&128~=0 then
  if r(0xc4)&32~=0 then horizontal=horizontal+1 else vertical=vertical+1 end
 end
 assert((r(0x62)&31)<25,'long cliff must reach its lower floor alive: y='..r(0x64)..' camera='..descent..' c4='..r(0xc4)..' phase='..r(0xc5)..' worldRow='..r(0xa0)..' horizontal='..horizontal)
 if not floor then
  for a=0x40c,0x4cb do w(a,0)end
  if descent>=128 then
   floor=true
   local row=(11+r(0x93))%12
   for x=0,15 do w(0x40c+row*16+x,1)end
  end
 elseif r(H.M_STATE)==0 then
  landed=landed+1
  local world=r(0x64)+descent
  support=support or world;assert(world==support,'landing stays attached to lower ground while the camera scrolls')
 else landed=0;support=nil end
 assert(updates<300,'bounded long cliff must reach the lower ground, camera='..descent)
end,emu.callbackType.exec,0xf28d)
emu.addEventCallback(function()
 f=f+1
 if landed>=4 then
  assert(descent>=128 and vertical>=56,'at least eight native vertical terrain strips exercised')
  assert(MOVE==false or horizontal>=16,'competing horizontal camera strips exercised')
  assert(support-72>=200,'tall cliff drop must exceed 200 world pixels: '..(support-72))
  print('PASS tall cliff: '..updates..' updates, '..(support-72)..' pixel fall, '..descent..' camera pixels, '..horizontal..' horizontal / '..vertical..' vertical updates, four supported landings');emu.stop(0)
 end
 assert(f<1800,'bounded tall-cliff replay')
end,emu.eventType.endFrame)
