dofile(TEST_ROOT..'/tests/common.lua')
local entered=nil
local submenu=nil
local back=nil
emu.addMemoryCallback(function()entered=entered or f end,emu.callbackType.exec,H.MenuGate)
emu.addEventCallback(function()
 local pad={}
 if not entered then pad.start=f%90<4
 else
  local t=f-entered
  if r(0x78a1)==0 then
   pad.down=not back and t==40
   pad.a=not back and t==45 or back and f-back==20
  elseif r(0x78a1)==1 then
   submenu=submenu or f
   pad.b=f-submenu==25
  elseif r(0x78a1)==2 and r(N.gameMode)==2 then
   pad.right=f%30==10;pad.start=f%90<4
  else pad.start=f%90<4 end
 end
 setPad(0,pad);setPad(1,{})
end,emu.eventType.inputPolled)
local function ppu(a)return emu.read(a,emu.memType.nesPpuDebug)end
function tick(t)
 if entered and f-entered==25 then
  assert(ppu(0x21cd)==0x1c and ppu(0x224d)==0x1f and ppu(0x21cc)==0xff,'main menu text leaves a clear cursor gap')
  assert(r(0x203)==84 and r(0x207)==180,'both menu arrows sit outside the labels')
  screenshot('main-menu')
 end
 if submenu and f-submenu==20 then
  assert(ppu(0x21d0)==0x0c and ppu(0x2250)==0x11,'submenu renders CPU and HUMAN with matching spacing')
  screenshot('vs-menu')
 end
 if submenu and r(0x78a1)==0 and not back then back=f end
 if t>5 then
  assert(back and r(0x78a0)==0 and r(N.gameType)==1,'B returns to main and Solo retains the native B-Type menu')
  finish('main/submenu graphics, D-pad/A/B navigation and unchanged Solo A/B selection')
 end
end
