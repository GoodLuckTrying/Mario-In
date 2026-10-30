-- Fixed controller replay, with native enemy invulnerability to keep it repeatable.
local f=0
local booted=false
local draws=0
local work=0
local updates=0
local started=nil
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addMemoryCallback(function()
 if f>=700 then started=emu.getState()['cpu.cycleCount'] end
end,emu.callbackType.exec,0xc77b)
emu.addMemoryCallback(function()
 if started then work=work+emu.getState()['cpu.cycleCount']-started;updates=updates+1;started=nil end
end,emu.callbackType.exec,0xc841)
emu.addMemoryCallback(function() if f>=700 then draws=draws+1 end end,emu.callbackType.exec,0xc837)
emu.addEventCallback(function()
 setPad(0,{start=not booted and f%90<4,right=(COOP and not booted and f%30<4) or (f>=700 and f<1100),
  b=f>=700 and f<1100,a=(f>=750 and f<780) or (f>=900 and f<930)})
 setPad(1,{right=COOP and f>=700 and f<1100,b=COOP and f>=700 and f<1100,a=COOP and f>=760 and f<790})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end
 if f==700 then w(0x6804,POWER or 0);if COOP then w(0x6884,POWER or 0) end end
 if f>650 then w(0x5e,121);if COOP then w(0x5f,121) end end
 if f==1100 then
  local avg=math.floor(work/updates)
  print('PERFORMANCE form '..(POWER or 0)..' coop '..tostring(COOP)..' updates '..draws..'/400 average CPU cycles '..avg)
  if BASELINE then
  elseif COOP then
   assert(draws>=200 and avg<37000,'Co-op frame work must stay below the prior 42304-cycle average')
  else
   assert(draws>=350 and avg<25000,'Opening movement must avoid the prior sustained 30 fps slowdown')
  end
  if (POWER or 0)==0 and not COOP and not BASELINE then assert(draws>=380,'Small Mario opening replay must remain close to 60 fps') end
  print('PASS performance');emu.stop(0)
 end
end,emu.eventType.endFrame)
