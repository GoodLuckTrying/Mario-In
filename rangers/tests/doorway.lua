-- Native loader places the unmodified satellite doorway on screen.
-- Controller input then approaches it; neither exit tiles nor room flags are seeded.
local f=0
local p=PLAYER or 0
local power=POWER or 0
local base=0x6800+p*128
local coop=COOP or false
local twoPlayers=coop or p==1
local booted=false
local seeded=false
local triggered=false
local entered=false
local carried=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
local function tile(x,y)
 local a=0x600+(6%2)*128+math.floor(y/32)*16+math.floor(x/16)
 local v=r(a);return y%32>=16 and math.floor(v/16) or v%16
end
emu.addEventCallback(function()
 for q=0,1 do
  local b=q==p and ((CARRY and f>=710 and (RUN and f<930 or f<718)) or (not CARRY and RUN and f>=740 and f<930))
  setPad(q,{start=q==0 and not booted and f%90<4,right=(q==0 and twoPlayers and not booted and f%30<4) or (q==p and not entered and f>=740 and f<930),b=b})
 end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if seeded or r(0x31)~=0 then return end
 seeded=true
 local page,row=6,1
 local index=row*r(0x2e)+page
 w(0xfd,page);w(0xfb,row);w(0x22,index);w(0x23,index)
 for q=0,1 do
  w(0x500+q,page);w(0x520+q,row);w(0x4f0+q,q==p and 96 or 56);w(0x510+q,180)
 end
end,emu.callbackType.exec,0xe103)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if f>=740 and s['cpu.x']==p and r(0x31)==0 and r(0x500+p)==6 then
  triggered=true
  local ptr=r(0x34)+r(0x35)*256
  assert(r(0x10)==5 and r(ptr+r(0x22))%32==1,'Actual doorway must dispatch its native room-1 header')
 end
end,emu.callbackType.exec,0xeb10)
emu.addMemoryCallback(function()
 if triggered and emu.getState()['cpu.x']==1 and r(0x6c)==1 then entered=true end
end,emu.callbackType.exec,0xe576)
emu.addEventCallback(function()
 f=f+1
 if seeded and r(0x4d0)>=128 then booted=true end
 if seeded then for q=0,1 do w(0x5e+q,121) end end
 if f==690 then
  assert(r(0xfd)==6 and r(0xfb)==1 and r(0x22)==13,'Native loader must load the real boss approach map cell')
  assert(tile(192,160)==5 and tile(192,176)==5 and tile(208,176)==3,'Unmodified satellite doorway and surrounding metal wall must be present')
  w(0x50,twoPlayers and 1 or 0)
  for q=0,1 do
   w(0x4d0+q,(q==p or coop) and 0x80 or 0);w(0x54+q,(q==p or coop) and 0 or 12);w(0x56+q,0)
   w(0x6804+q*128,power)
  end
 end
 if f==709 and CARRY then
  local s=2
  w(0x4d0+s,0x80);w(0x400+s,0x90);w(0x4e0+s,0x10);w(0x420+s,0x22);w(0x570+s,0x81)
  w(0x4f0+s,110);w(0x500+s,6);w(0x510+s,180);w(0x520+s,1)
  w(0x560+s,0xff);w(0x550+s,0xab);w(0x480+s,0);w(0x490+s,0);w(0x4a0+s,0)
 end
 if f>=720 and f<740 then carried=carried or r(0x56+p)>=0x82 end
 if f==735 then
  if CARRY then assert(carried,'Native crate must be picked up before walking through the doorway') end
  if p==0 and power==2 and not coop and not CARRY and not RUN then
   local o=assert(io.open(TEST_ROOT..'/build/door-approach.png','wb'));o:write(emu.takeScreenshot());o:close()
  end
 end
 if f==1100 then
  print('DOOR player '..p..' form '..power..' run '..tostring(RUN)..' coop '..tostring(coop)..' carry '..tostring(CARRY)..' triggered '..tostring(triggered)..' entered '..tostring(entered)..' xy '..r(0x500+p)..':'..r(0x4f0+p)..' y '..r(0x520+p)..':'..r(0x510+p)..' camera '..r(0xfd)..':'..r(0xfb))
  assert(triggered and entered,'Walking into the actual satellite doorway must enter the native destination room')
  assert(r(0xfd)==0 and r(0xfb)==0 and r(0x6982)==1,'Native room load must return to live destination-room gameplay')
  assert(r(0x4d0+p)>=128 and r(base+4)==power,'Doorway entry must preserve the entering player and form')
  if coop then assert(r(0x4d0+1-p)>=128 and r(0x6804+(1-p)*128)==power,'Co-op partner must enter in the same form') end
  if CARRY then assert(r(0x56+p)==0,'Native room transition must release the outside crate') end
  for i=0,3 do assert(r(0x69a0+i)==0,'Entering the destination room must clear custom fireballs') end
  if p==0 and power==2 and not coop and not CARRY and not RUN then
   local o=assert(io.open(TEST_ROOT..'/build/door-entered.png','wb'));o:write(emu.takeScreenshot());o:close()
  end
  print('PASS real satellite doorway');emu.stop(0)
 end
end,emu.eventType.endFrame)
