local f=0
local entered=nil
local samples={}
local late=0
local writes=0
local maxLine=-999
local step=0
local stackRoom=255
local nmis=0
local nmiBase=nil
local stackLow=255
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,right=t>=120 and t<1000,b=t>=120 and t%18<6,a=t>=150 and t%180<80});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f;step=step+1
 if IS_CANDIDATE then emu.write(0x4f0,(r(0x4f0)&0xfe)|0x40,emu.memType.nesDebug)end
end,emu.callbackType.exec,IS_CANDIDATE and H.Step or 0xdae4)
emu.addMemoryCallback(function()
 if not entered then return end
 local s=emu.getState();local line=s['ppu.scanline'];local cycle=s['ppu.cycle']
 if r(0x39)&0x18~=0 then
  assert(line>=240 or line<0,'rendering resumes before the visible frame')
  maxLine=math.max(maxLine,line);samples[#samples+1]={line,cycle}
 end
end,emu.callbackType.exec,0xc220)
emu.addMemoryCallback(function(a,v)
 if not entered then return end
 local s=emu.getState();writes=writes+1
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled'] then late=late+1 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function()
 if not entered or not IS_CANDIDATE then return end
 local task=r(0);local sp=emu.getState()['cpu.sp']
 local previousSp=(sp+3)&255
 local pc=r(0x100+((sp+2)&255))+256*r(0x100+((sp+3)&255))
 -- The scheduler changes task $00 before restoring its stack. Attribute that
 -- transition to the actual interrupted stack, not the newly selected task.
 local bottom=previousSp&0xe0
 if not(pc>=0xc2bc and pc<0xc3dc) and task>=2 and task<=14 and task%2==0 then
  local top=r(0xc3bc+task);bottom=top-31
  assert(previousSp>=bottom and previousSp<=top,'normal execution retains its own coroutine stack')
 end
 nmiBase=bottom;stackRoom=math.min(stackRoom,sp-bottom);nmis=nmis+1
 assert(sp>=bottom,'NMI hardware entry retains its interrupted stack allocation')
end,emu.callbackType.exec,0xc0f0)
emu.addMemoryCallback(function(a,v)
 if nmiBase and a<0x100+nmiBase+32 then
  assert(a>=0x100+nmiBase,'NMI transfer must not overflow into the neighboring coroutine stack')
  stackLow=math.min(stackLow,a-0x100-nmiBase)
 end
end,emu.callbackType.write,0x100,0x1ff)
emu.addMemoryCallback(function()nmiBase=nil end,emu.callbackType.exec,0xc277)
emu.addEventCallback(function()
 f=f+1
 if entered and f-entered==1600 then
  local out=assert(io.open(TEST_ROOT..'/build/'..(IS_CANDIDATE and 'candidate' or 'original')..'-timing.json','w'))
  out:write(string.format('{"frames":1600,"updates":%d,"late_vram":%d,"vram_writes":%d,"max_reenable_scanline":%d,"samples":[',step,late,writes,maxLine))
  for i,s in ipairs(samples)do if i>1 then out:write(',')end;out:write(string.format('[%d,%d]',s[1],s[2]))end
  out:write(']}');out:close()
  assert(late==0,'no visible-rendering VRAM writes')
  print('stack NMI samples '..nmis..' minimum entry headroom '..stackRoom..' lowest actual slot '..stackLow)
  print('PASS timing; updates '..step..' max reenable line '..maxLine..' late VRAM '..late);emu.stop(0)
 end
 assert(f<4500,'timing replay completes')
end,emu.eventType.endFrame)
