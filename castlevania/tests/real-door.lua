local frame=0;local door=false;local captures={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120,right=frame>=710,b=frame>=710,up=frame>=1600,a=frame>=1250 and frame<1550 and frame%100<25},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 frame=frame+1
 if frame>700 then w(0x600d,90);w(0x6001,2);w(0x45,64) end
 if frame>=710 and r(0x18)==5 and r(0x19)==6 and (r(0x28)==0 or r(0x28)==1) then
  local camera=r(0x2e)+256*r(0x2f)
  local limit=r(0x28)==0 and 512 or 1280
  if camera>limit then print('FAIL running escaped scroll lock '..camera..' > '..limit);emu.stop(1);return end
 end
 if r(0x18)==8 then
  door=true
  local phase=r(0x19)
  if not captures[phase] then captures[phase]=true;print('door phase '..phase..' x '..r(0x38c)..' scroll '..r(0x2e)..' screen '..r(0x2f));local f=io.open((TEST_ROOT..'/analysis/real-door-')..phase..'.png','wb');f:write(emu.takeScreenshot());f:close() end
 end
 if frame==1800 then local f=io.open((TEST_ROOT..'/analysis/door-stuck.png'),'wb');f:write(emu.takeScreenshot());f:close();print('action '..r(0x46c)..' dir '..r(0x3c)..' x '..r(0x38c)..' y '..r(0x3f)) end
 if frame%300==0 then print('frame '..frame..' stage '..r(0x28)..' mode '..r(0x18)..' world '..r(0x40)+256*r(0x41)..' scroll '..r(0x2e)..' screen '..r(0x2f)) end
 if r(0x28)>=2 and r(0x18)==5 and door then print('Real running-speed door approach and transition passed');emu.stop(0) end
 if frame==2800 then print('FAIL real door replay');emu.stop(1) end
end,emu.eventType.endFrame)
