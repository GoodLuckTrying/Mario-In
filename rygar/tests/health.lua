local f=0;local started=nil;local initial=nil;local injured=false;local dying=false;local spawns=0;local last=-999
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{start=not started and f>=120 and f%60<2})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()spawns=spawns+1 end,emu.callbackType.exec,H.SpawnReset)
emu.addMemoryCallback(function()
 started=started or f;initial=initial or r(0xcb)
 if r(0xcb)<initial then injured=true end
 if r(0x492)&16~=0 or r(0xcb)>=128 then dying=true end
 if r(0x492)&48==0 and f-last>=130 and not dying then
  for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
  w(0x494,240);w(0x4a4,2);w(0x4b4,8);w(0x514,r(0x512));w(0x4f4,r(0x4f2)+4);w(0x5be,192)
  last=f
 end
end,emu.callbackType.exec,0x9B9A)
emu.addEventCallback(function()
 f=f+1
 if injured and dying and(r(0x301)==8 or r(0x492)==0 or spawns>=2)then
  print('PASS native energy damage and death/game-over progression');emu.stop(0)
 end
 assert(f<3000,'bounded energy/death replay; HP '..r(0xcb)..' injury '..tostring(injured)..' death '..tostring(dying))
end,emu.eventType.endFrame)
