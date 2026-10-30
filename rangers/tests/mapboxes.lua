-- Cold boot, untouched opening terrain. Only player position/form is seeded.
local f=0
local p=PLAYER or 0
local power=POWER or 0
local facing=LEFT and 2 or 1
local upper=UPPER or false
local b=0x6800+p*128
local booted=false
local picked=false
local heldApproach=false
local pickupFrame=0
local targetX=upper and (LEFT and 48 or 32) or (LEFT and 240 or 224)
local targetY=upper and 48 or 176
local standX=upper and (LEFT and 72 or 24) or (LEFT and 264 or 216)
local standY=upper and 52 or 180
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function tile(x,y)
 local a=0x600+(math.floor(x/256)%2)*128+math.floor(y/32)*16+math.floor(x%256/16)
 local v=r(a)
 return y%32>=16 and math.floor(v/16) or v%16
end
emu.addEventCallback(function()
 for q=0,1 do
  setPad(q,{start=q==0 and not booted and f%90<4,b=q==p and f>=720 and f<760,
   left=q==p and MOVING and LEFT and f>=720 and f<760,
   right=q==p and MOVING and not LEFT and f>=720 and f<760})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f>=720 and r(0x6980)==p then
  pickupFrame=f
  heldApproach=heldApproach or r(0x14+p)%128<64
 end
end,emu.callbackType.exec,0xcb19)
local seeded=false
emu.addMemoryCallback(function()
 if seeded or f<720 then return end
 seeded=true

  assert(tile(targetX,targetY)==15,'Target must be an actual untouched opening map box')
  w(0x98,0);w(0x50,1)
  for q=0,1 do
   w(0x4d0+q,q==p and 0x80 or 0);w(0x54+q,q==p and 0 or 12);w(0x56+q,0);w(0x5e+q,0)
  end
  for q=2,15 do w(0x4d0+q,0) end
  local x=standX+(MOVING and (LEFT and 12 or -12) or 0)
  w(0xfc,not upper and LEFT and 64 or 0);w(0xfd,0)
  w(0x68+p,x);w(0x6a+p,math.floor(x/256))
  w(0x4f0+p,x);w(0x500+p,math.floor(x/256));w(0x510+p,standY);w(0x520+p,5);w(0x400+p,LEFT and 0x90 or 0xd0)
  for i=0,0x4f do w(b+i,0) end
  w(b,0x4d);w(b+4,power);w(b+11,facing);w(b+12,facing)
  w(b+0x14,1);w(b+0x15,8);w(b+0x1b,0x70);w(b+0x37,0)
  if MOVING then w(b+6,LEFT and 0xcc or 0x34) end
end,emu.callbackType.exec,0xc77b)
emu.addEventCallback(function()
 f=f+1
 if r(0x31)==0 and r(0x4d0)>=128 then booted=true end

 if f>=721 and f<760 and r(0x56+p)>=0x82 then picked=true end
 if DEBUG and f>=720 and f<741 then print('DBG '..f..' xy '..r(0x500+p)..':'..r(0x4f0+p)..' y '..r(0x520+p)..':'..r(0x510+p)..' native '..r(0x54+p)..' flags '..r(0x400+p)..' smb '..r(b)..' face '..r(b+11)..' power '..r(b+4)..' speed '..r(b+6)..' cam '..r(0xfd)..':'..r(0xfc)..' carry '..r(0x56+p)..' throw '..r(b+0x2d)) end
 if f==760 then
  assert(picked,'B must lift the actual '..(upper and 'upper-platform' or 'lower stacked')..' map box from '..(LEFT and 'its right' or 'its left')..' side')
  assert(tile(targetX,targetY)==0,'Native pickup must remove the correct map box')
  assert(r(b+4)==power,'Background box pickup preserves form')
  if MOVING then assert(heldApproach,'Held run B must pick up on approach after the initial button edge') end
  print('PASS actual map box player '..p..' form '..power..' upper '..tostring(upper)..' left '..tostring(LEFT)..' run '..tostring(MOVING)..' pickup frame '..pickupFrame)
  emu.stop(0)
 end
end,emu.eventType.endFrame)
