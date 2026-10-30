MODE=MATCH_MODE or 0
dofile(TEST_ROOT..'/tests/common.lua')
local rounds=0;local roundAt=nil;local seeded=false;local resultAt=nil;local intro=false;local title=false;local unsafe=0
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 rounds=rounds+1;roundAt=f;seeded=false
end,emu.callbackType.exec,0xA038)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end
if first then local s=emu.getState();s['cpu.pc']=0xB70B;emu.setState(s)end end,emu.callbackType.exec,0xB6BB)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 assert(not first,'a completed match must not jump to the hardware reset vector')
end,emu.callbackType.exec,0xFF22)
emu.addMemoryCallback(function()
 local s=emu.getState();local line=s['ppu.scanline']
 assert(line<0 or line>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'all scene/HUD/name/portrait uploads stay inside blanking')
end,emu.callbackType.write,0x2007)
function input(t)
 local m=mode()
 if m==0x846f then return{select=r(0x12c)~=MODE and f%8==1,start=r(0x12c)==MODE and f%8==3}
 elseif m==0xd911 then return{a=f%8==3}
 elseif m==0x87db then
  local target=r(0x12b)==255 and 2 or(HUMAN or 0)
  return{down=r(0x6d)~=target and f%8==1,a=r(0x6d)==target and r(0x18)&127==1 and f%8==3}
 elseif m==0xb42d then return{start=resultAt and f-resultAt>120 and f%30==3}
 elseif m~=0xabff and m~=0xa038 then return{start=f%60==5}end
 return{}
end
function tick(t)
 if first and rounds==1 and not seeded and f-roundAt>=150 then
  -- A referee fixture isolates post-victory scene handling; full physical
  -- damage/pin sequences are separately tested without these state writes.
  seeded=true;w(0xa2,255);w(0xa3,0);w(0xcc,1);w(0xcb,0);w(0x9f,45);w(0xa0,1);w(0xa1,3);w(0x93,255)
 end
 if mode()==0xb42d then resultAt=resultAt or f;if f-resultAt==60 then screen('after-victory-result-'..MODE)end end
 if resultAt and mode()==0xbd62 then intro=true end
 if resultAt and mode()==0xbe95 then title=true end
 if rounds==2 and f-roundAt>150 then
  assert(resultAt and WWF_RASTER_FRAMES>250,'results and a second playable match were fully reached')
  if MODE==0 then assert(intro and title,'Standard intentionally returns through the original intro/title before another match')
  else assert(not intro and not title,'Tournament advances to its next opponent')end
  screen('after-victory-next-match-'..MODE)
  finish('complete victory/results/scene flow, original Standard versus Tournament behavior, safe graphics uploads and a second playable match')
 end
end
