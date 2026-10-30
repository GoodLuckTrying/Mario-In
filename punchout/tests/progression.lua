local f=0;local seeded=false;local down=false;local advanced=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f%120<3});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if seeded or f<2100 or r(4)~=255 or r(0x50)~=1 or r(0x98)>=128 or r(0xb7)~=0 then return end
 seeded=true
 -- Third knockdown of the round, with a native-valid shot at the open head plane.
 w(0x3ca,2);w(0x3d1,2);w(0x399,1);w(0x398,1)
 w(0x6010,8);w(0x6012,r(0xb0));w(0x6014,math.max(104,r(0xb1)-72)+2);w(0x6016,1)
 print('SEED finishing fireball '..f..' special '..r(0x3cb)..' BB '..r(0xbb)..' body '..r(0xb0)..':'..r(0xb1))
end,emu.callbackType.exec,0xa6ba)
emu.addMemoryCallback(function()
 if seeded and r(5)==1 and r(0x398)==0 then down=true end
end,emu.callbackType.exec,0xa6bd)
emu.addEventCallback(function()
 f=f+1
 if seeded and f%500==0 then print('TRACE '..f..' fight '..r(1)..' HP '..r(0x398)..':'..r(0x399)..' KD '..r(5)..' count '..r(0x3ca)..' state '..r(0x90)..' mac '..r(0x50)..' hit '..r(0x6024)..' age '..r(0x6010))end
 if down and r(1)==1 then advanced=true end
 if advanced then
  local o=assert(io.open(TEST_ROOT..'/build/next-opponent.png','wb'));o:write(emu.takeScreenshot());o:close()
  assert(r(0x6024)>0,'finishing damage used the fireball native-hit bridge')
  print('PASS finishing fireball enters native knockdown/TKO and advances to Von Kaiser at '..f);emu.stop(0)
 end
 assert(f<10000,'finishing fireball must advance through the referee and result sequence')
end,emu.eventType.endFrame)
