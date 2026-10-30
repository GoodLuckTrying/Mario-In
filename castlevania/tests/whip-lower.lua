-- Actual Down/B edges and native crouch updates; directed attack targets and
-- metasprite byte checks distinguish lowered damage from graphics alone.
local frame=0
local cases={}
for power=0,2 do for facing=0,1 do for _,lower in ipairs({false,true}) do
 cases[#cases+1]={start=700+#cases*35,power=power,facing=facing,lower=lower}
end end end
for power=0,2 do for facing=0,1 do for _,mode in ipairs({'release','press'}) do
 cases[#cases+1]={start=700+#cases*35,power=power,facing=facing,lower=mode=='release',mode=mode}
end end end
local pending=nil
local before=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function current()
 for _,case in ipairs(cases) do if frame>=case.start and frame<case.start+35 then return case end end
end
local function lowered(case,t)
 if case.mode=='release' then return t<10 end
 if case.mode=='press' then return t>=10 and t<27 end
 return case.lower and t<27
end
emu.addEventCallback(function()
 local case=current()
 emu.setInput({start=frame==120,b=case and frame==case.start,down=case and lowered(case,frame-case.start)},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local case=current()
 if not case then return end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 if frame==case.start then
  w(0x6001,case.power);w(0x603e,0);w(0x6039,0);w(0x600d,90);w(0x5b,0);w(0x45,64)
  w(0x46c,0);w(0x3f,176);w(0x354,176);w(0x38c,80);w(0x40,80);w(0x41,0);w(0x2e,0);w(0x2f,0);w(0x48,0)
  w(0x6071,0);w(0x6072,0);w(0x6073,0);w(0x6070,0);w(0x607f,0);w(0x6076,case.facing+1);w(0x450,case.facing)
 end
end,emu.callbackType.exec,0x934c)
emu.addMemoryCallback(function()
 local case=current()
 if not case then return end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
 if frame==case.start+12 then
  pending=case;before=r(0x603f)
  w(0x434+8,1);w(0x300+8,0);w(0x488+8,0);w(0x38c+8,80+(case.facing==0 and 20 or -20))
  local normal=r(0x3f)+(case.power==0 and 8 or -4)
  w(0x354+8,normal+r(0xe46d)+6)
 end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if not pending then return end
 local case=pending;pending=nil
 local lower=lowered(case,frame-case.start)
 assert(r(0x603f)==before+(lower and 1 or 0),'Low whip contact: power '..case.power..' facing '..case.facing..' down '..tostring(lower))
 local expected=lower and (case.power==0 and 4 or 8) or 0
 assert(r(0x606a)==expected,'Down crouch must lower the strike hitbox')
 w(0x434+8,0);w(0x6039,0)
end,emu.callbackType.exec,0xe8f0)
emu.addEventCallback(function()
 frame=frame+1
 local case=current()
 if not case then return end
 if frame==case.start+1 then assert(r(0x603e)==24,'Down+B must start a whip in native crouch') end
 if frame==case.start+15 then
  local body=case.power==0 and 2 or 4
  local base=case.power==0 and 0xf4 or 0xdc
  local lower=lowered(case,frame-case.start) and (case.power==0 and 4 or 8) or 0
  assert(r(0x6160+body*4+1)==(base+2*lower)%256,'Whip graphic must match its lower hitbox')
  if case.power>0 and lower>0 then assert(r(0x6162)==116,'Grown Mario must show the SMB crouch pose') end
  print('Whip height case: power '..case.power..', facing '..case.facing..', down '..tostring(lower>0)..', mode '..tostring(case.mode))
 end
 if frame==case.start+28 then assert(r(0x603e)==0,'Holding Down/B must not repeat the swing') end
 if frame==cases[#cases].start+29 then emu.stop(0) end
end,emu.eventType.endFrame)
