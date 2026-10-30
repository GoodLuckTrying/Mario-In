dofile(TEST_ROOT..'/tests/common.lua')
local file=assert(io.open(TEST_ROOT..'/build/portrait.chr','rb'));local mario=file:read('*a');file:close()
file=assert(io.open(TEST_ROOT..'/build/mario-stats.bin','rb'));local mstats=file:read('*a');file:close()
file=assert(io.open('C:/nes/WWF WrestleMania (USA).nes','rb'));local original=file:read('*a');file:close()
file=assert(io.open(TEST_ROOT..'/build/native-stats.bin','rb'));local nstats=file:read('*a');file:close()
local outgoingHuman=false;local transition=false;local slideFrames=0;local portraitFrames=0;local textFrames=0;local captured=false
local function cpuVisible()return (MODE or 0)==0 and r(0x12b)==255 and not outgoingHuman end
function menuInput()
 local p={};local q={};local pad=r(0x6e)%2==0 and p or q
 if r(0x18)&127==1 then
  local target=cpuVisible()and 4 or(((MODE or 0)>0 and r(0x6e)%2 or(HUMAN or 0)))
  if r(0x6d)~=target then pad.down=f%8==1 else pad.a=f%8==3 end
 end
 return p,q
end
-- The engine has committed the human choice, but its portrait still has
-- an outgoing animation. A007 changes choices only after it is hidden.
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()==0x87DB and r(0x12b)==254 then outgoingHuman=true;transition=true end
end,emu.callbackType.exec,0x87AD)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()==0x87DB and outgoingHuman then outgoingHuman=false end
end,emu.callbackType.exec,0xA007)
local function expectedPortrait()
 if not cpuVisible()then return mario end
 local a=16+0xE10+r(0x6d)*2
 local ptr=original:byte(a+1)+original:byte(a+2)*256
 return original:sub(16+ptr-0x8000+1,16+ptr-0x8000+576)
end
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0x87DB then return end
 local expected=expectedPortrait()
 for i=0,575 do assert(emu.read(0x980+i,emu.memType.nesPpuDebug)==expected:byte(i+1),'displayed portrait remains correct throughout its entrance, confirmation and exit; byte '..i)end
 if outgoingHuman and r(0x12b)==255 then slideFrames=slideFrames+1 end
 portraitFrames=portraitFrames+1
end,emu.callbackType.exec,0x8914)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if mode()~=0x87DB then return end
 local cpu=cpuVisible();local stats=cpu and nstats or mstats
 local offset=r(0x6d)*72
 for row=0,5 do for col=0,11 do
  assert(emu.read(0x2012+row*32+col,emu.memType.nesPpuDebug)==stats:byte(offset+row*12+col+1),'stats/name remain paired with the moving portrait')
 end end
 if not cpu then
  for i,v in ipairs({0x30,0x27,r(0x6d)==0 and 0x16 or 0x1a})do assert(emu.read(0x3f00+i,emu.memType.nesPpuDebug)==v,'the outgoing brother retains his colors')end
 end
 textFrames=textFrames+1
end,emu.callbackType.exec,0x8917)
function tick(t)
 if outgoingHuman and r(0x6f)==0x80 and not captured then screen('portrait-outgoing-'..(HUMAN or 0));captured=true end
 if mode()==0xDBF8 then
  if(MODE or 0)==0 then assert(transition and slideFrames>25 and captured,'the confirmed brother completed its entire visible exit before CPU selection')end
  assert(portraitFrames>150 and textFrames==portraitFrames,'every selection frame was checked against actual portrait pixels and text')
  finish('every-frame portrait CHR, paired stats/colors, confirmed human exit, original CPU entrance and selection completion')
 end
end
