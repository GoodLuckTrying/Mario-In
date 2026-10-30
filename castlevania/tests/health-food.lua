-- Controlled native enemy/food contact, stage damage and live HUD fixtures.
local frame=0
local case=nil
local stageBefore=0
local health={64,56,48,16,56,64,64,4}
local expected={56,48,48,40,64,52,48,0}
local actor=19
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame>=700 then for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end end
 if frame<700 or frame>1400 or (frame-700)%100~=0 then return end
 case=math.floor((frame-700)/100)
 stageBefore=r(0x28)
 w(0x6001,(case==0 or case==4) and 2 or 0);w(0x600d,case==2 and 50 or 0);w(0x5b,0);w(0x45,health[case+1]);w(0x44,health[case+1])
 w(0x46c,0);w(0x3f,176);w(0x354,176);w(0x47,0);w(0x6004,0);w(0x6005,0);w(0x6006,0)
 w(0x6020,0);w(0x6021,0);w(0x603e,0)
 for _,base in ipairs({0x300,0x338,0x450,0x46c,0x488,0x4a4,0x568,0x584,0x530,0x4dc}) do w(base+actor,0) end
 w(0x434+actor,1);w(0x38c+actor,r(0x38c));w(0x354+actor,184);w(0x31c+actor,0x50)
 if case==3 or case==4 then
  w(0x434+actor,0x2f);w(0x584+actor,5);w(0x4c0+actor,0x10);w(0x31c+actor,0x4b)
 elseif case==5 then w(0x28,7)
 elseif case==6 then w(0x28,12)
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if case==nil then return end
 assert(r(0x45)==expected[case+1],'Native health/food case '..case..': got '..r(0x45))
 assert(r(0x6001)==((case==0 or case==4) and 2 or 0),'Healthy hits and food must preserve size')
 if case==0 or case==1 or case==5 or case==6 then assert(r(0x600d)>0 and r(0x5b)>0,'Damage must grant invincibility') end
 if case==3 or case==4 then assert(r(0x434+actor)~=0x2f,'Native food must be consumed') end
 print('Native health/food case '..case..' passed: HP '..r(0x45))
 w(0x28,stageBefore);w(0x434+actor,0)
 if case==7 then emu.stop(0) end
 case=nil
end,emu.callbackType.exec,0xcf1c)
emu.addEventCallback(function()
 frame=frame+1
 local n=math.floor((frame-700)/100)
 if n>=0 and n<=6 and (frame-700)%100==70 then
  assert(r(0x44)==expected[n+1],'Displayed health must catch up with actual health')
  local bars=0
  for address=0x2000,0x20bf do if emu.read(address,emu.memType.nesPpuDebug)==0xda then bars=bars+1 end end
  assert(bars==math.floor(expected[n+1]/8),'Native HUD health bar must reflect damage and food: '..bars)
  print('Health HUD case '..n..' passed')
 end
 if frame==1450 then print('FAIL missing health fixture');emu.stop(1) end
end,emu.eventType.endFrame)
