local f=0
local p=PLAYER or 0
local mode=MODE or 'valid'
local jingles=0
local pulses=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 for q=0,1 do
  local code=q==p
  local a=code and ((f>=560 and f<566) or (f>=580 and f<586))
  local b=code and ((f>=540 and f<546) or (f>=600 and f<606))
  if mode=='held-a' then a=code and f>=560 and f<586 end
  if mode=='wrong' then a=code and f>=540 and f<546;b=code and f>=560 and f<566 end
  setPad(q,{start=q==0 and ((f>=200 and f<210) or (mode~='outside' and ((f>=500 and f<506) or (f>=650 and f<656)))),up=code and mode~='no-up' and f>=520 and f<630,a=a,b=b})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=650 and emu.getState()['cpu.a']==0x36 then jingles=jingles+1 end
end,emu.callbackType.exec,0xec1e)
emu.addMemoryCallback(function() if f>=650 and f<720 then pulses=pulses+1 end end,emu.callbackType.write,0x4000,0x4007)
emu.addEventCallback(function()
 f=f+1
 if f==515 and mode~='outside' then assert(r(0x15)==1,'Start must pause') end
 if f==625 then
  assert(r(0x7005)==0,'Invincibility must wait until unpause')
  if mode=='valid' then assert(r(0x7006)==1,'Separate Up+B,A,A,B presses must arm the code') end
 end
 if f==720 then
  assert(r(0x15)==0,'Start must unpause')
  assert(r(0x7005)==(mode=='valid' and 1 or 0),'Only the valid paused code enables invincibility')
  assert(jingles==(mode=='valid' and 1 or 0),'The activation jingle must be requested exactly once')
  if mode=='valid' then assert(pulses>10,'Confirmation jingle must reach the APU') end
  print('PASS paused cheat '..mode..' controller '..p);emu.stop(0)
 end
end,emu.eventType.endFrame)
