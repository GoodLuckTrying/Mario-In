-- Native stairs in stage 02, including both directions through the room seam.
-- Player placement starts each fixture; actual Up/Down drives the native stair code.
local root=(TEST_ROOT..'/')
local frame,number,tick,steps,colors,roomChanges=0,0,0,0,0,0
local phase='boot';local lastStep=0;local startY=0;local sawStair=false;local initialRoom=1
local cases={}
for power=0,2 do for _,kind in ipairs({'floor','room'}) do cases[#cases+1]={power=power,kind=kind} end end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function launch()
 number=number+1;tick=0;steps=0;sawStair=false;phase='loading'
 if not cases[number] then
  assert(colors>1000 and roomChanges>=6,'Stairs must exercise palettes and room changes')
  print('Stair transitions passed: '..#cases..' native round trips; '..colors..' palette checks, '..roomChanges..' room changes')
  emu.stop(0);phase='done';return
 end
 local c=cases[number]
 w(0x28,2);w(0x600b,2);w(0x46,1);w(0x48,0);w(0xe2,0);w(0x2d,0);w(0x2e,0);w(0x2f,c.kind=='room' and 1 or 0);w(0x18,5);w(0x19,0)
end
local function place()
 local c=cases[number];local x=c.kind=='room' and 112 or 176;local y=c.kind=='room' and 192 or 128
 w(0x38c,x);w(0x40,x);w(0x41,c.kind=='room' and 1 or 0);w(0x3f,y);w(0x354,y);w(0x46c,0);w(0x434,0);w(0x47,0);w(0x5b,0);w(0x45,64);w(0x44,64);w(0x6001,c.power);w(0x6059,255);w(0x142,0);w(0x3c,4);w(0x49,0);w(0x3a8,0)
 for _,a in ipairs({0x6002,0x6003,0x6004,0x6005,0x6006,0x6013,0x6020,0x6021,0x6039,0x603e,0x6070,0x6071,0x6072,0x6073,0x6074,0x6075,0x607f}) do w(a,0) end
 w(0x6076,1);w(0x6077,1);startY=y;initialRoom=1;lastStep=frame;tick=0;phase='down'
end
emu.addEventCallback(function() emu.setInput({start=frame==120,down=phase=='down',up=phase=='up'},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if phase=='down' or phase=='up' then
  steps=steps+1;lastStep=frame;w(0x600d,90);w(0x45,64)
  -- Isolate the native stair/room sequence from unrelated combat.
  for slot=3,22 do w(0x434+slot,0);w(0x31c+slot,0);w(0x60a0+slot,0) end
 end
end,emu.callbackType.exec,0x934c)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then launch() end
 if phase=='loading' and r(0x18)==5 and r(0x19)==6 then place() end
 if phase=='down' or phase=='up' then
  tick=tick+1
  if r(0x46)~=initialRoom then roomChanges=roomChanges+1;initialRoom=r(0x46) end
  if r(0x18)==5 and r(0x19)==6 then
   assert(frame-lastStep<8,'Stair engine stopped updating')
   if r(0x46c)==4 then sawStair=true end
   if tick>4 and frame-lastStep<=2 then
    local want=cases[number].power==2 and {0x37,0x27,0x16} or {0x16,0x27,0x18}
    for i=1,3 do assert(emu.read(0x3f10+i,emu.memType.nesPpuDebug)==want[i],'Mario palette changed on stairs: case '..number..' direction '..phase..' room '..r(0x46)..' color '..i);colors=colors+1 end
    assert(r(0x6240+24)==0xfe,'Complete native palette command must retain its terminator')
    for i=6,24 do assert(r(0x6240+i)==emu.read(0x1cde9+i,emu.memType.nesPrgRom),'Every non-Mario native palette byte must remain intact') end
   end
   if sawStair and r(0x46c)==0 then
    if phase=='down' then
     assert(r(0x3f)~=startY,'Down must traverse the real stairs')
     if cases[number].kind=='room' then assert(r(0x46)==0,'Descending stairs must enter the lower room') end
     phase='up';tick=0;sawStair=false
    else
     assert(r(0x46)==1 and math.abs(r(0x3f)-startY)<=2,'Up must return to the starting platform/room')
     assert(r(0x6001)==cases[number].power and r(0x45)==64,'Stairs must retain size and health')
     print('Native stair round trip '..number..' passed');launch()
    end
   end
  else lastStep=frame end
  assert(tick<500,'Native stair round trip timeout: case '..number..' direction '..phase..' action '..r(0x46c)..' pos '..r(0x40)+256*r(0x41)..'/'..r(0x3f))
 end
 assert(frame<5000,'Stair fixture timeout')
end,emu.eventType.endFrame)
