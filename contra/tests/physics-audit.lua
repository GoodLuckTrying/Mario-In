-- Confirm the standalone CPU audit against the actual installed ROM in Mesen.
-- Each isolated case uses a flat solid floor, no enemies, and a fixed camera.
local fixtures=dofile(TEST_ROOT..'/build/physics-repair/fixtures.lua')
local p=PLAYER or 0
local cases={}
for _,case in ipairs(fixtures)do if case.player==p then cases[#cases+1]=case end end
local f=0;local which=1;local tick=1;local running=false;local returnAddress=nil
local b=0x6000+128*p
local offsets={2,3,4,5,6,7,8,9,10,11,12,22,23,24,25,26,27,28,29,30}
local measured={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local function afterMove()
 if not running or r(0x6101)~=p then return end
 local case=cases[which];local expected=case.trace[tick]
 for _,off in ipairs(offsets)do
  assert(r(b+off)==expected.port[off+1],string.format('%s P%d power%d tick%d offset%02X expected%d actual%d',case.scenario,p,case.power,tick-1,off,expected.port[off+1],r(b+off)))
 end
 assert(r(N.SPRITE_X_POS+p)==expected.x and r(N.SPRITE_Y_POS+p)==expected.y,'native game coordinates match standalone port execution')
 measured[#measured+1]={case.scenario,case.power,tick-1,r(N.SPRITE_Y_POS+p),r(b+24),r(b+25),expected.source_y,expected.source_vy,expected.source_vyfrac}
 tick=tick+1
 if tick>#case.trace or(case.scenario=='fast-jump-walk-off' and tick>130)then
  print('PASS live ROM physics trace P'..p..' power'..case.power..' '..case.scenario)
  tick=1;which=which+1
  if which>#cases then
   running=false
   local file=assert(io.open(TEST_ROOT..'/build/physics-audit/mesen-'..p..'.json','w'))
   -- Rows deliberately use positional arrays for easy JSON serialization.
   file:write('[')
   for i,row in ipairs(measured)do
    if i>1 then file:write(',')end
    file:write(string.format('[%q,%d,%d,%d,%d,%d,%d,%d,%d]',table.unpack(row)))
   end
   file:write(']');file:close()
   print('PASS '..#measured..' live movement updates against the audit on installed ROM')
   emu.stop(0)
  end
 end
end
emu.addEventCallback(function()
 local held=cases[which]and cases[which].trace[tick].held or 0
 for q=0,1 do
  setPad(q,{start=q==0 and(f==120 or f==200 or f==400),select=q==0 and f==180,
   a=q==p and f>=710 and(held&128)~=0,b=q==p and f>=710 and(held&64)~=0,
   left=q==p and f>=710 and(held&2)~=0,right=q==p and f>=710 and(held&1)~=0,
   down=q==p and f>=710 and(held&4)~=0})
 end
end,emu.eventType.inputPolled)
-- Isolate movement from the NES DMC controller-read glitch. A live DMC
-- sample can corrupt one of Contra's two reads (observed P2 $C3/$C1),
-- making its native filter retain last frame's buttons. Disable only DMC
-- in this fixture before polling; keep controller input and every exact
-- movement-state/coordinate assertion intact. Other replays retain audio.
emu.addMemoryCallback(function()
 if f>=710 then emu.write(0x4015,0x0f,emu.memType.nesMemory)end
end,emu.callbackType.exec,N.load_controller_state)
emu.addMemoryCallback(function()
 if f<710 or which>#cases or r(0x8000)~=8 then return end
 running=true
 local case=cases[which];local expected=case.trace[tick]
 if not returnAddress then
  local sp=emu.getState()['cpu.sp']
  returnAddress=r(0x100+sp+1)+256*r(0x100+sp+2)+1
  emu.addMemoryCallback(afterMove,emu.callbackType.exec,returnAddress)
 end
 for s=0,15 do w(N.ENEMY_ROUTINE+s,0);w(N.ENEMY_SPRITES+s,0)end
 w(0x604c,2);w(0x60cc,2)
 w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,250)
 w(N.VERTICAL_SCROLL,0);w(N.HORIZONTAL_SCROLL,0);w(N.LEVEL_STOP_SCROLL,255)
 for i=0,127 do w(N.BG_COLLISION_DATA+i,expected.floor and(i%64)//4==11 and 255 or 0)end
 w(N.SPRITE_X_POS+p,128);w(N.PLAYER_FAST_X_VEL_BOOST+p,0);w(N.PLAYER_ON_ENEMY+p,0)
 w(N.FRAME_SCROLL,0);w(N.PLAYER_FRAME_SCROLL+p,0)
 if tick==1 then
  for i=0,127 do w(b+i,0)end
  w(b,0x4d);w(b+4,case.power);w(b+11,1);w(b+12,1);w(b+20,1);w(b+21,8)
  w(b+27,0x70);w(b+32,255);w(b+55,r(N.CURRENT_LEVEL));w(b+76,2)
  w(N.SPRITE_Y_POS+p,164);w(N.PLAYER_HIDDEN+p,0);w(N.PLAYER_JUMP_STATUS+p,0)
 end
 -- Held input must arrive through the native input poll, not a RAM override.
 assert(r(N.CONTROLLER_STATE+p)==expected.held,'native controller bits reach the movement audit')
end,emu.callbackType.exec,H['P'..p..'Move'])
emu.addEventCallback(function()
 f=f+1
 assert(f<3500,'bounded physics replay')
end,emu.eventType.endFrame)
