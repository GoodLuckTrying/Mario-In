-- Native fish-man AI, splash/fireball helpers, contact and mixed actor dispatch.
-- Room/player placements are fixtures; enemy routines and controller input run normally.
local root=(TEST_ROOT..'/')
local manifest=assert(io.open(root..'build/patch-manifest.json','r'));local symbols=manifest:read('*a');manifest:close()
local function label(name) return assert(tonumber(symbols:match('"'..name..'": (%d+)'))) end
local frame,number,tick,steps=0,0,0,0;local phase='boot';local lastStep=0
local bankChecks,postChecks,contacts,splashes,shots,platformSteps=0,0,0,0,0,0
local pending=false;local cases={}
for _,area in ipairs({{stage=2,room=0},{stage=2,room=1},{stage=10,room=0}}) do
 for _,power in ipairs({0,2}) do for _,action in ipairs({0,4,6}) do for _,slot in ipairs({3,13}) do
  cases[#cases+1]={stage=area.stage,room=area.room,power=power,action=action,slot=slot}
 end end end
end
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function launch()
 number=number+1;tick=0;steps=0;pending=true;phase='loading'
 if not cases[number] then
  assert(bankChecks>100 and postChecks>100 and contacts>0 and splashes>=24 and shots>=12 and platformSteps>50,'Fixtures must exercise each native path')
  print('Native AI banks passed: '..#cases..' live enemy cases; '..bankChecks..' actor dispatches, '..postChecks..' Mario returns, '..contacts..' contacts, '..splashes..' splashes, '..shots..' shots, '..platformSteps..' platform updates')
  emu.stop(0);phase='done';return
 end
 local c=cases[number]
 w(0x28,c.stage);w(0x600b,c.stage);w(0x46,c.room);w(0x48,0);w(0xe2,0);w(0x2d,0);w(0x2e,c.stage==10 and 128 or c.room==0 and 128 or 0);w(0x2f,0);w(0x18,5);w(0x19,0)
end
local function setup()
 local c=cases[number]
 for slot=3,22 do
  for _,base in ipairs({0x300,0x31c,0x338,0x354,0x370,0x38c,0x3a8,0x3c4,0x3e0,0x3fc,0x418,0x434,0x450,0x46c,0x488,0x4a4,0x4c0,0x4dc,0x4f8,0x514,0x530,0x54c,0x568,0x584,0x60a0}) do w(base+slot,0) end
 end
 local x,y=64,112
 if c.room==1 then x=176;y=128 end
 if c.stage==10 then
  for slot=23,26 do if r(0x434+slot)==1 and r(0x31c+slot)==0xc9 then x=r(0x38c+slot);y=r(0x354+slot)-16;break end end
 end
 w(0x38c,x);w(0x40,x+r(0x2e));w(0x41,math.floor((x+r(0x2e))/256));w(0x3f,y);w(0x354,y);w(0x46c,0);w(0x434,0);w(0x47,0);w(0x5b,0);w(0x45,64);w(0x44,64);w(0x6001,c.power);w(0x600d,0);w(0x6059,255);w(0x142,0)
 for _,a in ipairs({0x6002,0x6003,0x6004,0x6005,0x6006,0x6013,0x6020,0x6021,0x6039,0x603e,0x6070,0x6071,0x6072,0x6073,0x6074,0x6075,0x607f}) do w(a,0) end
 w(0x6076,1);w(0x6077,1)
 local slot=c.slot
 w(0x434+slot,3);w(0x31c+slot,0x20);w(0x354+slot,c.slot==3 and y+16 or 100);w(0x38c+slot,c.slot==3 and x+4 or x+72);w(0x46c+slot,c.action);w(0x54c+slot,1);w(0x4c0+slot,4)
 if slot==13 then
  w(0x43c,8);w(0x31c+8,0x33);w(0x354+8,y);w(0x38c+8,x-60);w(0x4c0+8,0);w(0x54c+8,30)
 end
 pending=false;lastStep=frame
end
emu.addEventCallback(function() emu.setInput({start=frame==120,down=phase=='play' and cases[number].room==1,b=phase=='play' and tick>=16 and tick%25==0,a=phase=='play' and cases[number].stage==10 and tick>=40 and tick<46},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if phase=='play' then
  steps=steps+1;lastStep=frame;w(0x45,64)
  if r(0x606d)>0 then platformSteps=platformSteps+1 end
 end
end,emu.callbackType.exec,0x934c)
emu.addMemoryCallback(function() if phase=='play' and pending then setup() end end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if phase~='play' then return end
 local ai=r(0x4b);local target=r(0xe95c+ai*2)+256*r(0xe95d+ai*2)
 if target<0xc000 then assert(r(0x27)==5,'Native actor dispatch selected wrong bank for AI '..ai);bankChecks=bankChecks+1 end
end,emu.callbackType.exec,0xe959)
-- Banked addresses also contain unrelated platform code in bank 6. Check
-- the fixed trampoline immediately after mapping, before its banked jump.
if AI_PREVIOUS_RELEASE then
 emu.addMemoryCallback(function() if phase=='play' then assert(r(0x27)==5,'Mario pickup hook selected wrong bank') end end,emu.callbackType.exec,AI_CONVERT_ADDRESS)
else
 emu.addMemoryCallback(function() if phase=='play' then assert(r(0x27)==5,'Mario pickup hook selected wrong bank');postChecks=postChecks+1 end end,emu.callbackType.exec,label('PostNativeAi')+5)
 emu.addMemoryCallback(function() if phase=='play' then assert(r(0x27)==5,'Mario contact selected wrong bank');contacts=contacts+1 end end,emu.callbackType.exec,label('MarioDamage')+11)
end
emu.addMemoryCallback(function() if phase=='play' then splashes=splashes+1 end end,emu.callbackType.exec,0xfcb9)
emu.addMemoryCallback(function() if phase=='play' then shots=shots+1 end end,emu.callbackType.exec,0xfca2)
emu.addEventCallback(function()
 frame=frame+1
 if frame==700 then launch() end
 if phase=='loading' and r(0x18)==5 and r(0x19)==6 then phase='play';lastStep=frame end
 if phase=='play' then
  assert(frame-lastStep<8,'Native game logic stopped after an enemy helper: case '..number)
  tick=tick+1
  if tick==64 then assert(steps>=30,'Native enemy room must continue updating');print('Live native AI case '..number..' passed');launch() end
 end
 assert(frame<5000,'Native AI bank fixture timeout')
end,emu.eventType.endFrame)
