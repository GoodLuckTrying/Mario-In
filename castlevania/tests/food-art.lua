-- RAM fixture: hold the native meat pickup on screen, then collect it.
-- The reference option runs the same layout against the original local ROM.
local frame=0
local actor=19
local root=(TEST_ROOT..'/analysis/')
local reference=FOOD_ART_REFERENCE or false
local baseline=FOOD_ART_BASELINE or false
local tile=0x64
local rightTile=0x66
if not reference and not baseline then
 local manifest=assert(io.open(root..'../build/patch-manifest.json','r'));local data=manifest:read('*a');manifest:close()
 tile=assert(tonumber(data:match('"100": (%d+)')))
 rightTile=assert(tonumber(data:match('"102": (%d+)')))
end
local tag=reference and 'reference' or (baseline and 'before' or 'fixed')
local source=assert(io.open('C:/nes/Castlevania (USA) (Rev 1).nes','rb'))
source:seek('set',0x5018+0x64*16)
local pixels=source:read(64);source:close()
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function fixture()
 local n=math.floor((frame-700)/100)
 local elapsed=(frame-700)%100
 if n<0 or n>2 or elapsed>21 then return nil,nil end
 return n,elapsed
end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 then return end
 for x=3,27 do w(0x434+x,0);w(0x31c+x,0);w(0x60a0+x,0) end
 local n,elapsed=fixture()
 if n==nil then return end
 w(0x6001,n);w(0x600d,0);w(0x5b,0);w(0x46c,0)
 w(0x38c,64);w(0x3f,176);w(0x354,176);w(0x47,0)
 w(0x6004,0);w(0x6005,0);w(0x6006,0);w(0x6020,0);w(0x6021,0);w(0x603e,0)
 if elapsed==0 then w(0x45,n==2 and 56 or 16);w(0x44,r(0x45)) end
 for _,base in ipairs({0x300,0x338,0x488,0x4a4,0x530,0x4dc}) do w(base+actor,0) end
 w(0x434+actor,0x2f);w(0x584+actor,5);w(0x4c0+actor,0x10);w(0x31c+actor,0x4b)
 w(0x46c+actor,2);w(0x568+actor,180);w(0x450+actor,n%2)
 w(0x38c+actor,elapsed==21 and 64 or 120);w(0x354+actor,184)
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 local n,elapsed=fixture()
 if n==nil then return end
 if elapsed==21 then
  assert(r(0x45)==(n==2 and 64 or 40),'Meat must heal 24 HP with native cap')
  assert(r(0x434+actor)~=0x2f,'Meat must be consumed on contact')
  if not reference then assert(r(0x6001)==n,'Meat must preserve Mario power') end
  print('Food art and healing case '..n..' passed')
 elseif elapsed==10 then
  assert(r(0x434+actor)==0x2f and r(0x31c+actor)==0x4b,'Fixture must display live native food')
 end
end,emu.callbackType.exec,0xcf1c)
emu.addMemoryCallback(function()
 local n,elapsed=fixture()
 if n==nil or elapsed~=10 or r(0x05)~=actor then return end
 local found={}
 for address=0x244,0x2fc,4 do
  if r(address)==176 and (r(address+3)==112 or r(address+3)==120) then
   found[r(address+3)]={r(address+1),r(address+2)}
  end
 end
 local left,right=found[112],found[120]
 assert(left and right,'Meat must render both 8x16 halves')
 local facing=n%2
 assert(left[1]==(facing==0 and tile or rightTile) and right[1]==(facing==0 and rightTile or tile),'Meat must use the reserved original-art tiles')
 assert(left[2]==3+facing*0x40 and right[2]==3+facing*0x40,'Meat must preserve native palette and facing')
end,emu.callbackType.exec,0x80a8)
emu.addEventCallback(function()
 frame=frame+1
 local n=math.floor((frame-700)/100)
 if n>=0 and n<=2 and (frame-700)%100==12 then
  local f=assert(io.open(root..'food-'..tag..'-'..n..'.png','wb'));f:write(emu.takeScreenshot());f:close()
  for i=0,63 do
   local t=i<32 and tile or rightTile
   local addr=(t%2)*0x1000+math.floor(t/2)*32+i%32
   if not reference and not baseline then addr=addr+0x2000 end
   assert(emu.read(addr,emu.memType.nesChrRam)==pixels:byte(i+1),'Food CHR must match the original meat pixels')
  end
 end
 if frame==930 then emu.stop(0) end
 if frame==1000 then print('FAIL food fixture timeout');emu.stop(1) end
end,emu.eventType.endFrame)
