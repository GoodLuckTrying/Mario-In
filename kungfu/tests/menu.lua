local f=0
local mode=MODE or 3
local method=METHOD or 'select'
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local press=false
 for i=0,mode-1 do if f==80+i*20 then press=true end end
 local controls={start=f>=180 and f<190}
 if method=='select'then controls.select=press
 elseif method=='hold'then controls.down=f>=80 and f<140
 elseif method=='up'then controls.up=f==80
 else controls.down=press end
 setPad(0,controls);setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if f==170 then
  local expected=method=='hold' and 1 or method=='up' and 3 or mode
  print('Menu '..method..' selected '..r(0x54)..', expected '..expected)
  assert(r(0x54)==expected,'Each original game mode must be selectable without holding a direction cycling repeatedly')
 end
 if f==700 then
  local expected=method=='hold' and 1 or method=='up' and 3 or mode
  assert(r(0x50)==1 and r(0x51)==2,'Start must begin the selected game mode')
  assert(r(0x53)==(expected&1),'The selected A/B difficulty must reach the native engine')
  assert((r(0x5d)>0)==(expected>=2),'The selected one/two-player mode must allocate the correct lives')
  print('PASS menu '..method..' mode '..expected..' native difficulty '..r(0x53)..' P2 lives '..r(0x5d));emu.stop(0)
 end
end,emu.eventType.endFrame)
