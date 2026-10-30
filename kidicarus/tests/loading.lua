-- Observe the first unblank after native asset/player initialization.
local f=0
local stage=STAGE or 2
local pending=false
local checked=0
local errors={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
dofile(TEST_ROOT..'/tests/reload_stage.lua')
emu.addEventCallback(function() emu.setInput({start=f==120 or f==200},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function() if r(0xA0)==stage then pending=true end end,emu.callbackType.exec,0xC14D)
emu.addMemoryCallback(function()
 if emu.getState()['cpu.x']==0x20 and r(0xA0)==stage then pending=true end
end,emu.callbackType.exec,0xC3BF)
emu.addMemoryCallback(function(a,v)
 if not pending or (v & 0x18)==0 or r(0xA0)~=stage then return end
 pending=false;checked=checked+1
 local badChr=0
 for i=0,127 do
  if emu.read(i,emu.memType.nesPpuDebug)~=r(0x6900+i) then badChr=badChr+1 end
 end
 local badOam=0
 for slot=0,28,4 do
  if emu.read(slot,emu.memType.nesSpriteRam)<240 and emu.read(slot+1,emu.memType.nesSpriteRam)>7 then badOam=badOam+1 end
 end
 local badPalette=0
 for i=1,3 do if emu.read(0x3F10+i,emu.memType.nesPpuDebug)~=r(0x3A0+i) then badPalette=badPalette+1 end end
 print(string.format('unblank stage=%d frame=%d pose=%d wrong CHR bytes=%d wrong OAM=%d wrong palette=%d',stage,f,r(0x681F),badChr,badOam,badPalette))
 if r(0x6800)~=0x4D or badChr+badOam+badPalette>0 then errors[#errors+1]='Unblank exposes a partially initialized Mario' end
end,emu.callbackType.write,0x2001)
emu.addEventCallback(function()
 f=f+1
 if f==600 and stage~=2 then requestNativeStage(stage) end
 if f>=900 then
  assert(checked>0,'Observe native level unblank')
  assert(#errors==0,table.concat(errors,'; '))
  emu.stop(0)
 end
end,emu.eventType.endFrame)
