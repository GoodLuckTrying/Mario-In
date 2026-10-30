-- Controller-only opening: the two new-life supplies are real native items.
local f=0
local grew=false
local flower=false
local fired=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,right=f>=740 and f<860,b=f>=920 and f<928})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==735 then assert(r(0x6004)==0,'Mario must start small') end
 if f>=740 then
  if r(0x6004)==1 then grew=true end
  if r(0x6004)==2 then flower=true end
  if r(0x6180)>0 or r(0x6182)>0 then fired=true end
 end
 if f==1000 then
  print('Opening supplies: mushroom='..tostring(grew)..' flower='..tostring(flower)..' fire='..tostring(fired)..' x='..r(N.SPRITE_X_POS))
  assert(grew and flower and fired,'Walk to the supplied mushroom and flower, then fire with B')
  assert(r(0x604C)==2 and r(N.P1_GAME_OVER_STATUS)==0,'Deliver exactly two supplies and keep Mario alive')
  local o=assert(io.open(TEST_ROOT..'/build/supplies.png','wb'));o:write(emu.takeScreenshot());o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
