local f=0;local seeded=false;local active=0;local palettes=0;local late=0;local kd=false;local recovered=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 if not seeded then w(1,FIGHT);seeded=true;print('SEED native fight '..FIGHT)end
end,emu.callbackType.exec,0xaae5)
emu.addEventCallback(function()
 setPad(0,{start=f<1800 and f%150<3,b=f>=1800 and f%24<2,a=f>=1800 and f%24>=12 and f%24<14,up=f>=1800 and f%240<120,left=f>=1800 and f%200>=150 and f%200<154,down=f>=1800 and f%200>=175 and f%200<179});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(4)==255 and r(0x50)>0 and r(0x50)<64 then
  active=active+1
  assert(r(1)==FIGHT,'the native loader must retain the requested opponent')
  assert(r(0x69)==2,'Mario/referee background must use the private combined atlas')
 end
 if r(5)==2 then kd=true end
 if kd and r(5)==0 and r(0x392)>0 and r(0x50)==1 then recovered=true end
end,emu.callbackType.exec,0xa6cf)
emu.addMemoryCallback(function(a,v)
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled']then late=late+1 end
end,emu.callbackType.write,0x2006,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==2700 then
  local o=assert(io.open(TEST_ROOT..'/build/roster-'..FIGHT..'.png','wb'));o:write(emu.takeScreenshot());o:close()
 end
 if f==5000 then
  assert(seeded and active>300,'native fight must load and run')
  assert(late==0,'no out-of-vblank drawing for opponent '..FIGHT)
  print('PASS roster '..FIGHT..' active '..active..' spawns '..r(0x6025)..' hits '..r(0x6024)..' down '..tostring(kd)..' recovered '..tostring(recovered)..' late '..late)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
