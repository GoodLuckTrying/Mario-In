local f=0;local stage=0;local seededAt=0;local down=false;local recovered=false;local poses={};local captures={};local pending=nil;local late=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f%120<3});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<2100 or r(4)~=255 or r(0x50)~=1 or r(0x98)>=128 or r(0xb7)~=0 then return end
 if stage~=0 and not (stage==2 and recovered)then return end
 -- Native first-knockdown/get-up sequence, then third-knockdown TKO.
 if stage==2 then w(0x3ca,2);w(0x3d1,2)end
 w(0x399,1);w(0x398,1)
 w(0x6010,8);w(0x6012,r(0xb0));w(0x6014,math.max(104,r(0xb1)-72)+2);w(0x6016,1)
 stage=stage+1;seededAt=f
 print('SEED referee sequence '..stage..' at '..f)
end,emu.callbackType.exec,0xa6ba)
emu.addMemoryCallback(function()
 if stage==1 and r(5)==1 then down=true;stage=2 end
end,emu.callbackType.exec,0xa6bd)
emu.addMemoryCallback(function()
 local n=r(0x61)
 if n>=128 and n<175 then
  poses[n]=true
  local tag=n>=0x9a and n<=0xa3 and 'count' or n==0xa9 and 'tko' or n==0xa6 and 'fight' or n>=0x81 and n<=0x97 and 'walk' or nil
  if tag and not captures[tag]then pending=tag;captures[tag]=true end
 end
end,emu.callbackType.exec,0xa5ec)
emu.addMemoryCallback(function(a,v)
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled']then late=late+1 end
end,emu.callbackType.write,0x2006,0x2007)
emu.addEventCallback(function()
 f=f+1
 if pending then
  local o=assert(io.open(TEST_ROOT..'/build/referee-'..pending..'.png','wb'));o:write(emu.takeScreenshot());o:close();pending=nil
 end
 if stage==2 and down and f>seededAt+100 and r(5)==0 and r(0x399)>0 and r(0x50)==1 then recovered=true end
 if stage==3 and r(1)==1 then
  local count=0;for _ in pairs(poses)do count=count+1 end
  assert(recovered,'native first knockdown must get up')
  assert(captures.count and captures.fight and captures.tko,'walking, counting, Fight and TKO artwork must be displayed')
  assert(late==0,'referee transitions must fit vblank')
  print('PASS referee: '..count..' native poses, first knockdown/get-up, counting and third-knockdown TKO, zero late writes');emu.stop(0)
 end
 assert(f<14000,'native referee sequences must complete; stage '..stage..' down '..tostring(down)..' recovered '..tostring(recovered)..' pose '..r(0x61))
end,emu.eventType.endFrame)
