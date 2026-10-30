-- Controller-only route across the real Jungle's water and collapsing bridges.
-- Contact immunity isolates shoreline movement; terrain and actors stay native.
local f=0
local previous=0
local exits=0
local water=0
local history={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,right=f>=740,b=f>=740})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<730 then return end
 w(0x6004,POWER or 0);w(0x6035,0);w(0x604C,2);w(0x6049,255)
end,emu.callbackType.exec,H.MoveGate)
local function code(x,y)
 if y>=224 then return 0 end
 local world=x+r(N.HORIZONTAL_SCROLL)
 local nt=(r(N.PPUCTRL_SETTINGS)&1)~(math.floor(world/256)&1)
 local row=math.floor(((y+r(N.VERTICAL_SCROLL))%240)/16)
 local col=math.floor((world%256)/16)
 return (r(N.BG_COLLISION_DATA+nt*64+row*4+math.floor(col/4))>>((3-col%4)*2))&3
end
emu.addEventCallback(function()
 f=f+1
 if f>740 then
  local swimming=r(0x6047)
  if TRACE and f>1000 then
   local x=r(N.SPRITE_X_POS);local y=r(N.SPRITE_Y_POS)
   history[#history+1]=string.format('f%d s%d/%d x%d y%d vy%02X.%02X wet%d floor%d/%d/%d mask%d vs%d cap%d',f,r(N.LEVEL_SCREEN_NUMBER),r(N.LEVEL_SCREEN_SCROLL_OFFSET),x,y,r(0x6018),r(0x6019),swimming,code(x-8,y+12),code(x,y+12),code(x+7,y+12),r(N.PLAYER_HIDDEN),r(N.VERTICAL_SCROLL),r(0x604D))
   if #history>40 then table.remove(history,1) end
   if r(N.PLAYER_STATE)==2 then
    for _,line in ipairs(history) do print(line) end
    for row=10,13 do local line='' for col=0,15 do line=line..code(col*16,row*16) end print('row '..row..' '..line) end
    local o=assert(io.open(TEST_ROOT..'/build/water-failure.png','wb'));o:write(emu.takeScreenshot());o:close()
   end
  end
  if swimming~=0 then water=water+1 end
  if previous~=0 and swimming==0 and r(0x6005)==0 then
   exits=exits+1
   assert((r(N.SPRITE_Y_POS)+12+r(N.VERTICAL_SCROLL))%16==0,'A real shore exit must align the feet to its top')
  end
  previous=swimming
  if f>=800 then assert(r(N.PLAYER_STATE)==1,'The real Jungle water route must not clip/drown Mario: frame '..f..' state '..r(N.PLAYER_STATE)..' screen '..r(N.LEVEL_SCREEN_NUMBER)..' xy '..r(N.SPRITE_X_POS)..'/'..r(N.SPRITE_Y_POS)) end
 end
 -- Finish after the shoreline and bridge section, before the later native
 -- screen-7 pit that requires A. CPU/render changes can reach that pit
 -- earlier, so a fixed frame cutoff does not describe the route tested.
 if f==1700 or (f>1200 and r(N.LEVEL_SCREEN_NUMBER)>=6 and r(N.LEVEL_SCREEN_SCROLL_OFFSET)>=128) then
  print('Jungle water route: screen='..r(N.LEVEL_SCREEN_NUMBER)..' swim frames='..water..' walk-out exits='..exits)
  assert(water>100 and exits>=1 and r(N.LEVEL_SCREEN_NUMBER)>=4,'Exercise native water, shore and bridge transitions with Right+B, without A')
  local o=assert(io.open(TEST_ROOT..'/build/water-jungle.png','wb'));o:write(emu.takeScreenshot());o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
