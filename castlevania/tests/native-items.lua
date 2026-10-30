-- Controlled native money-bag and orb rendering/contact fixtures.
local frame=0
local actor=19
local root=(TEST_ROOT..'/')
local manifest=assert(io.open(root..'build/patch-manifest.json','r'))
local data=manifest:read('*a');manifest:close()
local function tile(original) return assert(tonumber(data:match('"'..original..'": (%d+)'))) end
local bagLeft,bagRight,orb=tile(96),tile(98),tile(80)
local source=assert(io.open('C:/nes/Castlevania (USA) (Rev 1).nes','rb'))
source:seek('set',0x5018+96*16);local bagPixels=source:read(64)
source:seek('set',0x5018+80*16);local orbPixels=source:read(32);source:close()
local scoreBefore=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function score() return r(0x7fc)..','..r(0x7fd)..','..r(0x7fe)..','..r(0x7ff) end
local function fixture()
 local n=math.floor((frame-700)/100)
 local elapsed=(frame-700)%100
 if n<0 or n>1 or elapsed>21 then return nil,nil end
 return n,elapsed
end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local n,elapsed=fixture();if n==nil then return end
 for x=3,27 do w(0x434+x,0);w(0x31c+x,0);w(0x60a0+x,0) end
 w(0x6001,2);w(0x600d,0);w(0x5b,0);w(0x46c,0);w(0x38c,64);w(0x3f,176);w(0x354,176);w(0x47,0)
 w(0x6004,0);w(0x6005,0);w(0x6006,0);w(0x6020,0);w(0x6021,0);w(0x603e,0)
 if elapsed==0 then w(0x45,16);w(0x44,16);scoreBefore=score() end
 for _,base in ipairs({0x300,0x338,0x488,0x4a4,0x530,0x4dc,0x450}) do w(base+actor,0) end
 w(0x434+actor,0x2f);w(0x584+actor,n==0 and 0x11 or 6)
 w(0x4c0+actor,n==0 and 0x0e or 0x23);w(0x31c+actor,n==0 and 0x49 or 0x32)
 w(0x46c+actor,2);w(0x568+actor,180)
 w(0x38c+actor,elapsed==21 and 64 or 120);w(0x354+actor,184)
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 local n,elapsed=fixture();if n==nil then return end
 if elapsed==21 then
  assert(r(0x6001)==2,'Native pickups must preserve fire power')
  if n==0 then
   assert(r(0x45)==16 and r(0x434+actor)==0x33 and score()~=scoreBefore,'Money bag pickup: HP '..r(0x45)..' AI '..r(0x434+actor)..' score '..score()..' before '..scoreBefore)
   print('Native money bag art and points passed')
  else
   assert(r(0x45)==64 and r(0x18)==12,'Native orb must heal fully and start stage completion')
   print('Native orb art and stage completion passed');emu.stop(0)
  end
 else
  -- Isolate the named static pose from animation timing for OAM inspection.
  w(0x31c+actor,n==0 and 0x49 or 0x32)
 end
end,emu.callbackType.exec,0xcf1c)
emu.addMemoryCallback(function()
 local n,elapsed=fixture();if n==nil or elapsed~=10 or r(5)~=actor then return end
 local found={}
 for a=0x244,0x2fc,4 do if r(a)==176 then found[r(a+3)]={r(a+1),r(a+2)} end end
 if n==0 then
  assert(found[112] and found[120] and found[112][1]==bagLeft and found[120][1]==bagRight,'Money bag must retain both original sprite halves')
 else assert(found[116] and found[116][1]==orb and found[116][2]==3,'Orb must retain its original sprite and palette') end
end,emu.callbackType.exec,0x80a8)
emu.addEventCallback(function()
 frame=frame+1
 local n,elapsed=fixture()
 if n~=nil and elapsed==12 then
  local file=assert(io.open(root..'analysis/native-'..(n==0 and 'bag' or 'orb')..'.png','wb'));file:write(emu.takeScreenshot());file:close()
  local pixels=n==0 and bagPixels or orbPixels
  for i=0,#pixels-1 do
   local t=n==1 and orb or (i<32 and bagLeft or bagRight)
   local address=8192+(t%2)*4096+(t&254)*16+i%32
   assert(emu.read(address,emu.memType.nesChrRam)==pixels:byte(i+1),'Native item must retain every original CHR pixel')
  end
 end
 if frame==950 then assert(false,'Native item fixture timeout') end
end,emu.eventType.endFrame)
