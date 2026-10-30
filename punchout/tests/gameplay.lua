local f=0
local updates=0
local maxAge=0
local poses={}
local late=0
local writes=0
local worst=-1
local lastSpawn=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function dump(tag)
 local pre=TEST_ROOT..'/build/play-'..tag
 local o=assert(io.open(pre..'.png','wb'));o:write(emu.takeScreenshot());o:close()
 o=assert(io.open(pre..'.ram','wb'));for a=0,0x7ff do o:write(string.char(r(a)))end;o:close()
 o=assert(io.open(pre..'.ppu','wb'));for a=0,0x3fff do o:write(string.char(emu.read(a,emu.memType.nesPpuDebug)))end;o:close()
end
emu.addEventCallback(function()
 setPad(0,{start=f<1600 and f%180<3,b=f>=1700 and f%32<2,up=f>=1700 and f%256<128,a=f>=1700 and f%32>=16 and f%32<18,left=f>=2400 and f%180>=100 and f%180<104,right=f>=2400 and f%180>=140 and f%180<144,down=f>=2400 and f%180>=70 and f%180<74});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 updates=updates+1
 poses[r(0x50)..':'..r(0x61)]=true
 if r(0x6025)~=lastSpawn then
  lastSpawn=r(0x6025)
  print('FIRE '..f..' spawn '..lastSpawn..' hits '..r(0x6024)..' mode '..r(4)..' status '..r(0x50)..' B '..r(0xd0)..' bank '..r(0xd)..' age '..r(0x6010)..','..r(0x6011))
 end
end,emu.callbackType.exec,0xa6bd)
emu.addMemoryCallback(function(a,v)
 local s=emu.getState();writes=writes+1
 local line=s['ppu.scanline']
 if line>=0 and line<240 and s['ppu.mask.backgroundEnabled']then late=late+1;worst=math.max(worst,line)end
end,emu.callbackType.write,0x2006,0x2007)
emu.addEventCallback(function()
 f=f+1;maxAge=math.max(maxAge,r(0x6010),r(0x6011))
 if f==1900 or f==2150 or f==2200 or f==2250 or f==2500 or f==3000 or f==4000 then dump(f)end
 if f==5000 then
  local count=0;for k in pairs(poses)do count=count+1 end
  print('RESULT updates '..updates..' spawns '..r(0x6025)..' hits '..r(0x6024)..' maxage '..maxAge..' poses '..count..' vram '..writes..' late '..late..' worst '..worst..' hp '..r(0x392)..' opp '..r(0x399))
  assert(r(0x6025)>10,'B must create actual fireballs')
  assert(maxAge>4,'fireballs travel over multiple native updates')
  assert(r(0x6024)>0,'fireballs must reach the native landed-hit path')
  assert(late==0,'no VRAM writes during rendering')
  print('PASS gameplay and VRAM deadlines');emu.stop(0)
 end
end,emu.eventType.endFrame)
