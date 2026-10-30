-- Load a native side room through its normal script dispatcher. Only the
-- room-entry fixture and one enemy contact are seeded; movement uses input.
local f=0
local room=ROOM or 0x26
local power=POWER or 2
local checked=0
local poses={}
local bad={}
local seededDamage=false
local leftX=nil
local rightX=nil
local started=0
local longest=0
local nmiDepth=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
dofile(TEST_ROOT..'/tests/reload_stage.lua')
local function issue(message)
 if #bad<8 then bad[#bad+1]='frame '..f..': '..message end
end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,a=f==900 or f>=980 and f<1010 or f>=1120 and f<1140,
  left=f>=1000 and f<1040,right=f>=1060 and f<1100},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if nmiDepth==0 then started=emu.getState()['cpu.cycleCount'] end
 nmiDepth=nmiDepth+1
end,emu.callbackType.exec,0xC866)
emu.addMemoryCallback(function()
 if nmiDepth==1 and f>=1000 and f<1250 then longest=math.max(longest,emu.getState()['cpu.cycleCount']-started) end
 nmiDepth=nmiDepth-1
end,emu.callbackType.exec,0xC89F)
emu.addMemoryCallback(function()
 if f<1250 or seededDamage or r(0xB6)~=8 or room~=0x22 or power==0 then return end
 seededDamage=true
 w(0x6804,power);w(0x682A,0);w(0x728,0);w(0x6835,0)
 w(0x6805,0);w(0x6818,0);w(0x6819,0);w(0x6806,0);w(0x6807,0);w(0x6808,0)
 for a=0x761,0x7D1,16 do w(a,0) end
 -- Native room enemy class $68 in its active state, at Mario's side.
 w(0x7C1,0x6A);w(0x7C0,r(0x720));w(0x7C3,r(0x723));w(0x7C2,0)
 w(0x7C4,0);w(0x7C5,0);w(0x7C6,0);w(0x7C7,1);w(0x7C8,0)
end,emu.callbackType.exec,0x8000)
emu.addMemoryCallback(function()
 if f<1000 or r(0x37)~=2 or r(0x38)~=0 or r(0x104)~=0 or r(0x4E2)>=0xF0 then return end
 local wrong=0
 for i=0,127 do if emu.read(i,emu.memType.nesPpuDebug)~=r(0x6900+i) then wrong=wrong+1 end end
 if wrong>0 then issue('room pose differs from PPU CHR ('..wrong..' bytes)') end
 checked=checked+1;poses[r(0x681F)]=true
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function()
 if f<1000 or r(0x38)~=0 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then issue(string.format('VRAM write during visible rendering line=%d pc=%04X bank=%d queue=%d text=%02X',s['ppu.scanline'],s['cpu.pc'],r(0xB6),r(0x104),r(0x4E2))) end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==500 and STAGE and STAGE~=2 then requestNativeStage(STAGE) end
 if f==600 then w(0x37,2);w(0x3A,2);w(0x3B,room);w(0x6804,power);w(0x728,0) end
 -- Keep the walking fixture alive until the deliberate damage contact.
 if f>=950 and f<1248 and room==0x22 then w(0x682A,255) end
 if f==1050 then leftX=r(0x723) end
 if f==1110 then rightX=r(0x723) end
 if f>=1000 and f<1250 and room==0x26 and r(0x68C5)==0 and r(0x4E2)==0 then
  for i=0,2 do
   local addr=0x21C9+i*5
   local price=r(0x4F1+i)
   assert(emu.read(addr,emu.memType.nesPpuDebug)==price>>4 and emu.read(addr+1,emu.memType.nesPpuDebug)==(price&15),'Shop prices must keep updating between pose transfers')
  end
 end
 if f==1253 and room==0x22 and power>0 then
  assert(seededDamage and r(0x6804)==0,'Native room enemy contact must shrink Mario')
  assert(r(0x682A)>0,'Damage must grant temporary invincibility')
 end
 if f==1310 and room==0x22 and power>0 then
  assert(r(0x6804)==0 and r(0x681E)==0,'Mario must retain his small form and collision size after damage')
  for i=0,63 do assert(emu.read(i,emu.memType.nesPpuDebug)==0,'Small Mario upper body tiles must be blank after shrinking') end
 end
 if f==1320 then
  local count=0;for _ in pairs(poses) do count=count+1 end
  print(string.format('Room=%02X power=%d left=%s right=%s pose checks=%d poses=%d max NMI=%d errors=%d',room,power,tostring(leftX),tostring(rightX),checked,count,longest,#bad))
  for _,v in ipairs(bad) do print(v) end
  assert(r(0x37)==2 and r(0x3B)==room,'Exercise the native room controller')
  if room==0x26 then assert(leftX and leftX<185 and rightX and rightX>leftX+20,'Mario must walk both directions inside the room') end
  assert(checked>100 and count>=3,'Exercise repeated native room pose updates')
  if room==0x26 then assert(longest<29780,'Shop animation must fit within one NTSC frame') end
  assert(#bad==0,'Room walking and damage graphics must reach the PPU safely')
  if CAPTURE then
   local o=assert(io.open(TEST_ROOT..'/build/rooms-'..CAPTURE..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  end
  emu.stop(0)
 end
end,emu.eventType.endFrame)
