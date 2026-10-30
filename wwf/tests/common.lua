f=0;first=nil;done=false
function r(a)return emu.read(a,emu.memType.nesDebug)end
function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
function mode()return r(0x27)+r(0x28)*256 end
function screen(name)
 local out=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));out:write(emu.takeScreenshot());out:close()
end
function finish(msg)print('PASS '..msg);done=true;emu.stop(0)end
if not REFERENCE_BOOT then dofile(TEST_ROOT..'/tests/graphics_oracle.lua')end
local function boot()
 local m=mode();local p={};local q={}
 if m==0x846F then
  if r(0x12c)~=(MODE or 0)then p.select=f%8==1 else p.start=f%8==3 end
 elseif m==0xD911 then
  if r(0x6e)%2==0 then p.a=f%8==3 else q.a=f%8==3 end
 elseif m==0x87DB then
  if menuInput then return menuInput()end
  local i=r(0x6e)+1
  if r(0x12b)==255 then i=2 end
  local target=(CHOICES or {0,1,0,1,0,1})[i]or 0
  if r(0x18)&127==1 then
   local pad=r(0x6e)%2==0 and p or q
   if r(0x6d)~=target then pad.down=f%8==1 else pad.a=f%8==3 end
  end
 elseif m~=0xABFF and m~=0xA038 then p.start=f%60==5 end
 return p,q
end
emu.addEventCallback(function()
 if done then return end
 local p,q
 if first then p=input and input(f-first)or{};q=input2 and input2(f-first)or{}else p,q=boot()end
 setPad(0,p or{});setPad(1,q or{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if r(0xc)==0 and mode()==0xABFF then first=first or f end
end,emu.callbackType.exec,H.DrawBridge)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 if tick then tick(first and f-first or -1)end
 assert(f<(MAX_FRAMES or 7000),'bounded WrestleMania replay, mode '..string.format('%04X',mode()))
end,emu.eventType.endFrame)
