local frame=0
local axeSeen=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function check(ok,msg) if not ok then print('FAIL '..msg);emu.stop(1) end end
emu.addEventCallback(function() emu.setInput({start=frame==120,up=frame==801,b=frame==801},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame==700 then
  w(0x46c,0);w(0x6001,2);w(0x6005,0);w(0x6004,0);w(0x6008,176);w(0x3f,160);w(0x354,160)
  w(0x603e,13);w(0x450,0)
  local x=10
  w(0x434+x,0x28);w(0x354+x,144);w(0x38c+x,r(0x38c)+24);w(0x300+x,0);w(0x6080+x,1);w(0x60e0+x,144);w(0x4dc+x,6);w(0x6100+x,6);w(0x6120+x,r(0x46));w(0x196,0);w(0x584+x,9)
  w(0x434+11,0x28);w(0x354+11,144);w(0x38c+11,240);w(0x300+11,0);w(0x6080+11,1);w(0x60e0+11,144);w(0x610b,r(0x4e7));w(0x612b,r(0x46))
 elseif frame==799 then
  w(0x38c+10,r(0x38c));w(0x354+10,r(0x3f));w(0x300+10,0)
 elseif frame==710 then
  w(0x434+12,0x30);w(0x584+12,3);w(0x354+12,100);w(0x38c+12,220)
  for x=13,15 do
   local ai=({4,5,0x2F})[x-12]
   w(0x434+x,ai);w(0x584+x,3);w(0x60a0+x,0);w(0x354+x,100);w(0x38c+x,210+(x-13)*10)
  end
  -- AI 0C is a jumping enemy, regardless of old bonus data in its slot.
  local x=16
  w(0x434+x,0x0C);w(0x584+x,3);w(0x60a0+x,0);w(0x354+x,160);w(0x38c+x,200)
  w(0x300+x,0);w(0x46c+x,0);w(0x54c+x,20);w(0x488+x,0);w(0x4c0+x,0x3C)
  w(0x72,255)
 end
end,emu.callbackType.exec,0xcf19)
emu.addEventCallback(function()
 frame=frame+1
 if frame>=802 and frame<850 then for x=20,22 do if r(0x434+x)~=0 then axeSeen=true end end end
 if frame==701 then
  check(r(0x196)==240,'Broken candle recorded in native persistence')
  check(r(0x434+10)==0x31 and r(0x60a0+10)==0,'Axe drop remains native pickup')
  check(r(0x434+11)==0x28 and r(0x354+11)==144,'Unstruck lamp must remain at its native position')
  print('Candle persistence and native weapon drop passed')
 elseif frame==711 then
  check(r(0x60a0+12)==3 and r(0x434+12)==4 and r(0x70)==2,'Whip converted to capped Mario drop')
  check(r(0x60af)==3 and r(0x443)==4,'Native whip pickup converts')
  for x=13,14 do check(r(0x434+x)==x-9 and r(0x60a0+x)==0,'Native inert enemy actor must remain intact') end
  check(r(0x72)==0,'Whip conversion releases native pickup reservation')
  check(r(0x434+16)==0x0C and r(0x60a0+16)==0,'Jumping enemy must remain an enemy')
  print('Whip upgrade conversion passed')
 elseif frame==712 then
  check(r(0x60cf)<159,'Converted pickup must expire normally without reconversion')
 elseif frame==800 then
  assert(r(0x15b)==9 and r(0x6001)==2,'Native axe must be collectible without shrinking Mario')
  print('Native candle axe pickup passed')
 elseif frame==805 then
  assert(r(0x71)==4 and r(0x6020)==0 and r(0x6021)==0,'Collected axe must fire with Up+B and cost one heart')
 elseif frame==850 then
  assert(axeSeen,'Collected axe projectile must spawn')
  print('Collected axe Up+B passed');emu.stop(0)
 end
end,emu.eventType.endFrame)
