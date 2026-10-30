MODE=2
dofile(TEST_ROOT..'/tests/common.lua')
local which=CASE or 1
local shooterIsP1=which==1 or which==3
local before=nil
local function bars()
 local a={};local b={}
 for i=0,4 do a[#a+1]=r(0x63d+i*4);b[#b+1]=r(0x651+i*4)end
 return table.concat(a,','),table.concat(b,',')
end
local function prepare(close)
 w(0x2d,100);w(0x2c,close and 120 or 170)
 for i=0,1 do
  w(0x2e+i,180);w(0x36+i,0);w(0x38+i,0);w(0x30+i,0);w(0x42+i,12)
  w(0x3c+i,0);w(0x3e+i,0);w(0x40+i,0);w(0x32+i,0);w(0x34+i,0)
  w(0x79+i,200);w(0x8e+i,0);w(0x94+i,0);w(0xa2+i,0);w(0xa4+i,0);w(0xcb+i,0)
  w(0x4cc+i,0);w(0x4ce+i,0);w(0x4d2+i,0)
 end
 w(0x3a,1);w(0x3b,0)
 w(shooterIsP1 and 0x7a or 0x79,192)
 for i=0,3 do w(0x4b0+i,0)end
end
function input(t)return{b=shooterIsP1 and t==110}end
function input2(t)return{b=which==2 and t==110,a=which==4 and t==110}end
function tick(t)
 if t<0 then return end
 if t==100 then prepare(which>=3)end
 if t==108 then local a,b=bars();before={a,b}end
 if t==200 then
  local a,b=bars()
  if shooterIsP1 then
   assert(r(0x79)==200,'P1 keeps its own energy when attacking P2, case '..which)
   assert(r(0x7a)<192,'P2 loses energy from P1 attack, case '..which)
   assert(a==before[1]and b~=before[2],'only the right on-screen energy bar changes after P1 attacks')
  else
   assert(r(0x7a)==200,'P2 keeps its own energy when attacking P1, case '..which)
   assert(r(0x79)<192,'P1 loses energy from P2 attack, case '..which)
   assert(b==before[2]and a~=before[1],'only the left on-screen energy bar changes after P2 attacks')
  end
  screen('damage-owner-'..which)
  finish('controller case '..which..': attack damages only the defender and its visible energy bar')
 end
end
