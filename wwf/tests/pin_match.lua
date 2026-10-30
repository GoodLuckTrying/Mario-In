MODE=TWO_PLAYER and 2 or 0
CHOICES={HUMAN or 0,TWO_PLAYER and ((HUMAN or 0)~1)or(OPPONENT or 0)}
dofile(TEST_ROOT..'/tests/common.lua')
local actor=ACTOR or 1;local target=actor~1
local downAt=nil;local pinStarted=false;local won=false;local full=false
local edgeReady=false;local stable=nil;local held=0
local function bot(t)
 if t<140 then return{}end
 if EDGE and edgeReady then return{down=true,a=true}end
 if pinStarted then return{}end
 local dx=r(0x2c+target)-r(0x2c+actor);local dy=r(0x2e+target)-r(0x2e+actor)
 local function toward()return{right=dx>0,left=dx<0}end
 if r(0xa2+target)==0 then
  if math.abs(dy)<=1 and r(0x3a+actor)~=(dx>0 and 0 or 1)then return toward()end
  return{b=t%20==1,up=dy < -1,down=dy > 1,right=(math.abs(dx)>85 and dx>0)or(math.abs(dx)<50 and dx<0),left=(math.abs(dx)>85 and dx<0)or(math.abs(dx)<50 and dx>0)}
 end
 downAt=downAt or t
 -- No seeded health, poses, defeat flags, coordinates or referee counts.
 -- Leave the wrestler alone long enough to prove it stays down.
 if t-downAt<(FREE_AI and 0 or 150)or r(0xa2+target)~=1 then return{}end
 if FREE_AI then
  -- Chase the visible fallen body, as a human does. Native knockdowns
  -- move artwork relative to the physical slot; chasing only the slot
  -- and tapping every 20 frames can miss a legal pin before a kick-out.
  -- Keep live AI, full energy and the actual three-count/winner checks.
  local function signed(v)return v>=128 and v-256 or v end
  dx=dx+signed(r(0x36+target))-signed(r(0x36+actor))
  dy=dy+signed(r(0x38+target))-signed(r(0x38+actor))-r(0x42+target)+r(0x42+actor)
  if math.abs(dy)>15 then return{up=dy<0,down=dy>0}end
  if math.abs(dx)>32 then return toward()end
  return{down=true,a=true}
 end
 if math.abs(dy)>4 then return{up=dy<0,down=dy>0}end
 if math.abs(dx)>21 then return toward()end
 if math.abs(dx)<12 then return{left=dx>0,right=dx<0}end
 if r(0x3a+actor)~=(dx>0 and 0 or 1)then return toward()end
 return{down=t%20==1,a=t%20==1}
end
function input(t)return actor==1 and bot(t)or{}end
function input2(t)return actor==0 and bot(t)or{}end
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if first and not TWO_PLAYER and not FREE_AI then local s=emu.getState();s['cpu.pc']=0xB70B;emu.setState(s)end
end,emu.callbackType.exec,0xB6BB)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if not first then return end
 assert(emu.getState()['cpu.x']==r(actor==1 and 0x12f or 0x130),'the pinning controller must be the match winner')
 won=true
end,emu.callbackType.exec,0xB385)
function tick(t)
 if t<0 then return end
 if FREE_AI and pinStarted and r(0xa2+target)==0 and r(0xa4+actor)==0 then pinStarted=false;downAt=nil end
 if TRACE and t%100==0 then print(string.format('t%d hp%d/%d xy%d,%d/%d,%d offset%d,%d/%d,%d act%d/%d down%d/%d pin%d/%d e7%d/%d face%d/%d c2%d',t,r(0x79),r(0x7a),r(0x2c),r(0x2e),r(0x2d),r(0x2f),r(0x36),r(0x38),r(0x37),r(0x39),r(0x3c),r(0x3d),r(0xa2),r(0xa3),r(0xa4),r(0xa5),r(0xe7),r(0xe8),r(0x3a),r(0x3b),r(0xc2)))end
 if t==140 and not FREE_AI then full=r(0x79)>190 and r(0x7a)>190;assert(full,'both wrestlers begin at full native energy')end
 if not FREE_AI and downAt and t-downAt==149 then assert(r(0xa2+target)~=0,'a defeated wrestler must remain down without repeated attacks')end
 if EDGE and downAt and t-downAt==150 then
  -- A position-only fixture places the naturally defeated opponent near
  -- a rope. Health, defeat, pin and referee state still come from play.
  local tx=EDGE==1 and 195 or 45
  local offset=r(0x36+target);if offset>=128 then offset=offset-256 end
  w(0x2c+target,tx);w(0x2e+target,197)
  w(0x2c+actor,tx+offset+(EDGE==1 and -32 or 32));w(0x2e+actor,187)
  edgeReady=true
 end
 if EDGE and r(0x4f6+actor)~=0 and mode()==0xABFF then
  held=held+1
  if held==30 then screen('held-pin-p'..actor..'-rope'..EDGE)end
  local xy={r(0x4ef+actor),r(0x4f1+actor)}
  if held>3 then
   assert(r(0x4d8+actor)==10,'the pinner must use the prone pose, rather than stand/slide')
   if stable then assert(xy[1]==stable[1]and xy[2]==stable[2],'holding Down+A must not jitter the pinner')end
   stable=xy
  end
 end
 if r(0xa4+actor)>0 then pinStarted=true end
 if mode()==0xB42D then
  assert(downAt and pinStarted and won and WWF_RASTER_FRAMES>500,'fireball defeat, sustained knockdown, physical Down+A, three-count and correct victory all complete')
  if EDGE then assert(edgeReady and held>100,'a sustained pin completes at the rope from the visible body range')end
  screen('pin-victory-'..(TWO_PLAYER and ('p'..(actor==1 and 1 or 2))or('cpu'..(OPPONENT or 0))))
  finish('full-energy controller fireballs -> persistent native defeat -> Down+A pin -> three-count -> correct winner, with native CPU sprite/raster audits')
 end
 assert(t<(MATCH_FRAMES or 2200),'controller-driven pin match must complete, actor '..actor..' opponent '..(OPPONENT or 0))
end
