-- Directed native camera fixtures for every stage/room boundary, then the
-- actual first-boss activation over two successive player updates.
local frame=0
local cases={}
local number=0
local active=nil
local saved={}
local boss=SCROLL_ONLY_BOSS or false
local bossSeeded=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local addresses={0x28,0x46,0x48,0x3c,0x3d,0x3e,0x38c,0x3a8,0x40,0x41,0x2d,0x2e,0x2f,0x49,0x6002,0x6003}
local function nibble(value,room) return room==0 and math.floor(value/16) or value%16 end
for stage=0,18 do for room=0,1 do
 local maximum=nibble(r(0xfbb0+stage),room)*256
 local sentinel=nibble(r(0xfbc3+stage),room)
 local minimum=sentinel==15 and 0 or (sentinel+1)*256
 local trigger=r(0xfc5e+stage)
 if math.floor(trigger/16)==room then maximum=math.min(maximum,trigger%16*256) end
 if minimum<=maximum then
  for _,fraction in ipairs({0,1,127,128,255}) do
   for _,speed in ipairs({24,40}) do
    for _,distance in ipairs({0,1,2,3}) do
     cases[#cases+1]={stage=stage,room=room,maximum=maximum,minimum=minimum,camera=math.max(minimum,maximum-distance),fraction=fraction,speed=speed,localX=127,flags=5}
     cases[#cases+1]={stage=stage,room=room,maximum=maximum,minimum=minimum,camera=math.min(maximum,minimum+distance),fraction=fraction,speed=-speed,localX=129,flags=6}
    end
    cases[#cases+1]={stage=stage,room=room,maximum=maximum,minimum=minimum,camera=maximum,fraction=fraction,speed=speed,localX=128,flags=1}
    cases[#cases+1]={stage=stage,room=room,maximum=maximum,minimum=minimum,camera=minimum,fraction=fraction,speed=-speed,localX=128,flags=2}
    cases[#cases+1]={stage=stage,room=room,maximum=maximum,minimum=minimum,camera=maximum,fraction=fraction,speed=speed,localX=127,flags=5,locked=true}
    cases[#cases+1]={stage=stage,room=room,maximum=maximum,minimum=minimum,camera=maximum,fraction=fraction,speed=-speed,localX=129,flags=6,locked=true}
   end
  end
 end
end end
emu.addEventCallback(function() emu.setInput({start=frame==120,right=boss and frame>=700,b=boss and frame>=700},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 or boss then return end
 number=number+1
 active=cases[number]
 if not active then return end
 for _,a in ipairs(addresses) do saved[a]=r(a) end
 w(0x28,active.stage);w(0x46,active.room);w(0x48,active.locked and 1 or 0)
 w(0x38c,active.localX);w(0x3a8,active.fraction);w(0x3c,active.flags)
 w(0x2e,active.camera%256);w(0x2f,math.floor(active.camera/256));w(0x2d,0);w(0x49,0)
 w(0x40,(active.camera+active.localX)%256);w(0x41,math.floor((active.camera+active.localX)/256))
 local velocity=active.speed*16
 w(0x6002,velocity%256);w(0x6003,math.floor(velocity/256))
end,emu.callbackType.exec,0x989a)
emu.addMemoryCallback(function()
 if not active then return end
 local case=active;active=nil
 local step=math.floor((case.fraction+case.speed*16)/256)
 local world=case.camera+case.localX+step
 local desired=case.camera+(case.flags<4 and step or case.speed>0 and math.max(0,case.localX+step-128) or math.min(0,case.localX+step-128))
 local expected=case.locked and case.camera or math.max(case.minimum,math.min(case.maximum,desired))
 local camera=r(0x2e)+256*r(0x2f)
 assert(camera==expected,'Camera boundary case '..number..': stage '..case.stage..' room '..case.room..' camera '..camera..' expected '..expected)
 assert(r(0x40)+256*r(0x41)==world,'Camera clipping must preserve world movement, case '..number)
 assert(r(0x3a8)==(case.fraction+case.speed*16)%256,'Camera clipping must preserve subpixels, case '..number)
 for a,value in pairs(saved) do w(a,value) end
 if number==#cases then boss=true;print('All '..#cases..' stage/room scroll boundary fixtures passed') end
end,emu.callbackType.exec,0x989d)
emu.addMemoryCallback(function()
 if frame<700 or not boss then return end
 if not bossSeeded then
  bossSeeded=true
  w(0x28,3);w(0x600b,3);w(0x46,0);w(0x48,0);w(0xe2,0)
  w(0x2e,255);w(0x2f,1);w(0x2d,0);w(0x3a8,0);w(0x38c,128);w(0x40,127);w(0x41,2)
  w(0x3f,176);w(0x354,176);w(0x46c,0);w(0x3c,1);w(0x6070,0)
  w(0x6071,40);w(0x6073,40);w(0x6076,1);w(0x6077,1);w(0x607f,0)
 end
 for a=0x5a0,0x6ff do w(a,0) end
 for _,base in ipairs({0x5a0,0x650}) do for x=0,7 do w(base+144+x,0x55) end end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 w(0x600d,90);w(0x45,64)
end,emu.callbackType.exec,0x934c)
emu.addMemoryCallback(function()
 if bossSeeded and r(0x48)~=0 then
  assert(r(0x2e)==0 and r(0x2f)==2,'First boss must lock at camera $0200')
  print('Running across the first-boss trigger activates the native lock');emu.stop(0)
 end
end,emu.callbackType.exec,0x9832)
emu.addEventCallback(function() frame=frame+1;if frame>700+#cases+100 then assert(false,'Scroll fixtures or boss activation timed out') end end,emu.eventType.endFrame)
