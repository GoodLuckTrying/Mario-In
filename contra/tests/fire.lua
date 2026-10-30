-- Hold each press for three video frames so a native lag frame cannot hide it.
local f=0
local stage=STAGE or 0
local p=PLAYER or 0
local b=0x6000+p*128
local shot=false
local bounced=false
local minY=255
local maxY=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function pad(i)
 return {start=i==0 and (f==120 or f==200 or f==400),select=i==0 and f==180,
  b=i==p and (f>=1000 and f<1003 or f>=1010 and f<1013 or f>=1020 and f<1023)}
end
emu.addEventCallback(function() setPad(0,pad(0));setPad(1,pad(1)) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<950 then return end
 for i=0,1 do w(0x604C+i*128,2);w(N.NEW_LIFE_INVINCIBILITY_TIMER+i,0xF0) end
 if f<980 then
  for s=0,15 do if r(N.ENEMY_TYPE+s)==0 then w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0) end end
  w(b+4,2);w(b+0x35,0)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addEventCallback(function()
 f=f+1
 if f==480 and stage~=0 then w(N.CURRENT_LEVEL,stage);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f>1000 and f<1040 then
  local count=0
  for s=0,3 do
   if r(0x6180+s)~=0 and r(0x61C0+s)==p then
    count=count+1;shot=true
    if stage==0 and r(0x6150+s)>=128 then bounced=true end
    local y=r(0x61A0+s);minY=math.min(minY,y);maxY=math.max(maxY,y)
   end
  end
  assert(count<=2,'Each player may have at most two fireballs')
  if f==1018 then assert(count==2,'Two fresh B presses must create two fireballs') end
 end
 if f==1060 then
  print('Fire player '..p..' stage '..stage..' shot '..tostring(shot)..' bounce '..tostring(bounced)..' y '..minY..'..'..maxY)
  assert(shot,'Fire form must shoot through normal controller input')
  if stage==0 then assert(bounced,'Outdoor fireballs must bounce on native terrain') end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
