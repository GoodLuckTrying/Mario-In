-- Controller-driven motion with the original terrain and music queues active.
-- Checking DMA/CHR alone missed the old bug: the *later* native scroll
-- restore crossed pre-render and made the displayed background jump.
local f=0;local selected=false;local checks=0;local uploads=0;local commits=0
local stage=STAGE or 0;local players=PLAYERS or 2
local dirs={{right=true},{right=true,down=true},{down=true},{left=true,down=true},
 {left=true},{left=true,up=true},{up=true},{right=true,up=true}}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 if not selected then w(0xaa,(stage-1)&255);selected=true end
end,emu.callbackType.exec,0x82bf)
emu.addMemoryCallback(function(a,v)
 if f<900 or r(0x7094)~=1 then return end
 local s=emu.getState();local pc=s['cpu.pc']
 if pc==0x8bf8 or pc==0x8c00 then
  local limit=pc==0x8bf8 and 257 or 280
  assert(s['ppu.scanline']>=241 or(s['ppu.scanline']==-1 and s['ppu.cycle']<limit),
   'native scroll restore missed pre-render: stage '..stage..' frame '..f..
   ' stream '..r(0x70b4)..' scan '..s['ppu.scanline']..' dot '..s['ppu.cycle'])
  checks=checks+1
 end
end,emu.callbackType.write,0x2005)
emu.addMemoryCallback(function()
 if f>=900 then uploads=uploads+1 end
end,emu.callbackType.exec,H.StreamNmi)
emu.addMemoryCallback(function()
 if f>=900 then commits=commits+1 end
end,emu.callbackType.exec,H.CommitDirections)
emu.addEventCallback(function()
 local t=f-900;local phase=(t//64)%8;local pad={start=f>=700 and f<710}
 if t>=0 and t%64<28 then for k,v in pairs(dirs[phase+1])do pad[k]=v end end
 pad.a=t>=0 and t%64>=10 and t%64<20
 pad.b=t>=0 and t%17<2
 setPad(0,pad);pad.start=false;setPad(1,players==2 and pad or{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1;if f==690 then w(0xb7,players==2 and 1 or 0)end
 if f>=900 then
  -- Form fixture only: motion, enemies, scroll queues, and audio stay native.
  for p=0,players-1 do w(0x7000+p,((f-900)//512)%3);w(0x3df+p,99)end
 end
 if f==2436 then
  assert(checks>1200,'sustained native scroll restores '..checks)
  assert(uploads>700 and commits>25,'sustained animation streaming '..uploads..'/'..commits)
  print('PASS stage '..stage..' P'..players..' controller walking/turns/jumps/fire in all forms; '..checks..' native scroll writes finish before pre-render reload')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
