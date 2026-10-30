-- Regress the animation-upload overrun: the old ROM resumed rendering on
-- visible line 1 whenever a walking pose changed. Forms/stages are fixtures;
-- walking, running and jumping still use the ordinary controller path.
local f=0
local stage=STAGE or 2
local power=POWER or 0
local bad={}
local masks=0
local nmis=0
local uploads=0
local poses={}
local watching=false
local latest=-1
dofile(TEST_ROOT..'/tests/reload_stage.lua')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local function failure(tag,s)
 if #bad<8 then bad[#bad+1]=string.format('%s frame=%d line=%d dot=%d PC=%04X',tag,f,s['ppu.scanline'],s['ppu.cycle'],s['cpu.pc']) end
end
emu.addEventCallback(function()
 local phase=(f-740)%100
 emu.setInput({start=f==120 or f==200,right=f>=740 and phase<30,left=f>=740 and phase>=35 and phase<65,b=f>=840,a=f>=940 and phase>=70 and phase<80},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 watching=f>=740 and r(0xA0)==stage and (r(0x37)==0 or ROOM_GAMEPLAY and r(0x37)==2) and r(0x38)==0
 if watching then nmis=nmis+1 end
 if watching and r(0x6821)~=0 and r(0x68BF)==0 and r(0x68A0)==0 then
  uploads=uploads+1;poses[r(0x681F)]=true
 end
end,emu.callbackType.exec,0xEB2E)
emu.addMemoryCallback(function(a,v)
 if not watching or (v & 0x18)==0 then return end
 local s=emu.getState()
 masks=masks+1
 local line=s['ppu.scanline']
 local dot=s['ppu.cycle']
 if line>=0 and line<240 or line==-1 and dot>=256 then failure('late rendering',s) end
 local elapsed=line==-1 and 20*341+dot or (line-241)*341+dot
 latest=math.max(latest,elapsed)
end,emu.callbackType.write,0x2001)
emu.addMemoryCallback(function()
 if not watching then return end
 local s=emu.getState()
 local line=s['ppu.scanline']
  if line>=0 and line<240 then failure('visible VRAM write bank '..r(0xB6),s) end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==600 and stage~=2 then requestNativeStage(stage) end
 if f==730 then
  w(0x6804,power)
  -- Fortress fixtures start at the native map overlay; enter gameplay.
  if not ROOM_GAMEPLAY and (stage==3 or stage==5 or stage==7) then w(0x37,0);w(0x3A,0) end
 end
 if f>=730 then w(0x682A,255) end
 if f>=1100 then
  local poseCount=0;for _ in pairs(poses) do poseCount=poseCount+1 end
  print(string.format('flicker stage=%d power=%d nmis=%d masks=%d uploads=%d poses=%d latest-dot-after-vblank-start=%d errors=%d',stage,power,nmis,masks,uploads,poseCount,latest,#bad))
  for _,v in ipairs(bad) do print(v) end
  assert(nmis>=100,'Exercise sustained native gameplay')
  assert(uploads>=(stage==8 and 1 or 10) and poseCount>=(stage==8 and 2 or 3),'Exercise repeated Mario animation changes')
  assert(#bad==0,'Animation must not delay rendering or VRAM writes into the visible frame')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
