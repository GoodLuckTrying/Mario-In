-- Native dropped-heart collection after obtaining fire power.
local f=0
local seeded={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=f==120 or f==200},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local at=f>=620 and 620 or f>=600 and 600 or nil
 if not at or seeded[at] then return end
 seeded[at]=true
 w(0x6804,2);w(0x723,48);w(0x720,170);w(0x721,0x80);w(0x6805,0)
 w(0x6818,0);w(0x6819,0);w(0x682A,0);w(0x682B,0);w(0x682C,0);w(0x6835,0)
 w(0x6806,0);w(0x6807,0);w(0x6808,0)
 w(0x6834,at==600 and 7 or 99);w(0x68AE,3)
 w(0x7C1,0x12);w(0x7C0,170);w(0x7C3,48);w(0x7C2,0xD0)
end,emu.callbackType.exec,0xCBB6)
emu.addEventCallback(function()
 f=f+1
 if f==605 or f==625 then
  assert(r(0x6804)==2,'Extra hearts must retain fire power')
  assert(r(0x682B)==0 and r(0x682C)==0,'Extra hearts must not grant star invincibility')
  assert(r(0x6835)==0,'Extra hearts must not trigger a power transformation')
  if f==605 then
   assert(r(0x6834)==8,'Heart must still advance its currency/life counter')
   print('Fire Mario extra heart retains fire power without a star')
  else
   assert(r(0x6834)==0 and r(0x68AE)==4,'100 heart units must still award a life')
   print('100 heart units award one life without star power')
   emu.stop(0)
  end
 end
end,emu.eventType.endFrame)
