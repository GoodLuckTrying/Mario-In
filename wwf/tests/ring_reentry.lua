-- Coordinate-only fixtures reproduce a body left outside the ring by a
-- transition. Native inputs/actions/collisions remain live throughout.
MODE=2
local actor=ACTOR or 1;local target=actor~1;local brother=HUMAN or 0
CHOICES=actor==1 and{brother,brother~1}or{brother~1,brother}
dofile(TEST_ROOT..'/tests/common.lua')
local cases={{120,208,'up'},{120,200,'up'},{120,168,'down'},{8,199,'right'},{242,199,'left'}}
local index=0;local at=nil;local start=nil;local checks=0;local hud=nil
local function buttons(t)
 if not at or t-at>=72 then return{}end
 return{[cases[index][3]]=true}
end
function input(t)return actor==1 and buttons(t)or{}end
function input2(t)return actor==0 and buttons(t)or{}end
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first then return end
 local t=f-first
 if t<120 or at and t-at<96 then return end
 if r(0x3c+actor)>4 then return end
 index=index+1
 if index>#cases then
  assert(checks==10,'all five fixtures must correct their bounds and then move under real input')
  finish('five ring-edge recoveries, actual inward movement, both axes, complete HUD patterns and legal PPU writes');return
 end
 local c=cases[index];at=t;start=nil
 w(0x2c+actor,c[1]);w(0x2e+actor,c[2])
 w(0x2c+target,180);w(0x2e+target,180)
end,emu.callbackType.exec,H.UpdateBridge)
emu.addMemoryCallback(function()
 if r(0xc)~=0 or not first then return end
 local t=f-first
 if t==60 then hud={};for a=0,0xbff do hud[a]=emu.read(a,emu.memType.nesPpuDebug)end end
 if hud and t%4==0 then for a=0,0xbff do
  assert(emu.read(a,emu.memType.nesPpuDebug)==hud[a],'HUD/portrait CHR changed during boundary recovery at '..string.format('%04x',a))
 end end
 if not at then return end
 local z=t-at;local x,y=r(0x2c+actor),r(0x2e+actor)
 if z==4 then
  assert(y>=169 and y<=199,'a free human must return inside the legal ring depth; got '..y)
  local depth=y-168
  assert(x>=51-depth and x<184+depth,'a free human must return inside the perspective side walls; got '..x)
  start={x,y};checks=checks+1
 elseif z==64 then
  assert(start,'check recovery before movement')
  local dir=cases[index][3]
  local moved=dir=='up'and y<=start[2]-4 or dir=='down'and y>=start[2]+4 or dir=='left'and x<=start[1]-4 or dir=='right'and x>=start[1]+4
  assert(moved,'real controller input must move back into the ring after '..dir..' recovery')
  assert(r(0x4f6+actor)==0 and r(0xcb+actor)==0 and r(0xe7+actor)==0,'boundary recovery must not leave a control/invulnerability lock')
  if index==1 then screen('ring-reentry-p'..actor..'-brother'..brother)end
  checks=checks+1
 end
end,emu.callbackType.exec,0xadfe)
emu.addMemoryCallback(function()
 if not first or mode()~=0xabff then return end
 local s=emu.getState()
 assert(s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled']),'native and custom VRAM writes must stay within blanking')
end,emu.callbackType.write,0x2007)
function tick(t)assert(t<1500,'bounded ring reentry controller replay')end
