-- Controlled terrain isolates camera, nametable streaming and page crossings.
local f=0
local updates=0
local cameraMoved=0
local badWrites={}
local lateRendering={}
local previousCamera=nil
local horizontal=HORIZONTAL or false
dofile(TEST_ROOT..'/tests/reload_stage.lua')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,right=horizontal and f>=730,b=horizontal and f>=730,a=not horizontal and f>=730},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<730 then return end
 updates=updates+1
 for a=0x500,0x6df do w(a,0) end
 for a=0x61,0xF1,8 do w(0x700+a,0) end
 w(0x6804,1);w(0x682A,255);w(0x728,0);w(0x37,0);w(0x38,0);w(0x6835,0)
 if horizontal then
  for x=0,15 do w(0x500+192+x,0x40);w(0x5F0+192+x,0x40) end
  w(0x720,184);w(0x6805,0);w(0x6818,0);w(0x6819,0);w(0x6806,40);w(0x6808,40)
 else
  w(0x720,100);w(0x723,128);w(0x6805,1);w(0x6818,252);w(0x6819,0);w(0x6817,0);w(0x681A,32);w(0x681B,112);w(0x681C,170)
 end
end,emu.callbackType.exec,0xCBB6)
emu.addMemoryCallback(function()
 if f<730 then return end
 local state=emu.getState()
 if state['ppu.scanline']>=0 and state['ppu.scanline']<240 and state['ppu.mask.backgroundEnabled'] then
  if #badWrites<8 then badWrites[#badWrites+1]=string.format('frame=%d scanline=%d PC=%04X',f,state['ppu.scanline'],state['cpu.pc']) end
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function(a,v)
 if f<730 or (v & 0x18)==0 then return end
 local s=emu.getState()
 local line=s['ppu.scanline']
 if line>=0 and line<240 or line==-1 and s['ppu.cycle']>=256 then
  if #lateRendering<8 then lateRendering[#lateRendering+1]=string.format('frame=%d line=%d dot=%d',f,line,s['ppu.cycle']) end
 end
end,emu.callbackType.write,0x2001)
emu.addEventCallback(function()
 f=f+1
 if f==600 and horizontal then
  requestNativeStage(4)
 end
 if f>=731 then
  local position=horizontal and (r(0x1B)*256+r(0xFE)) or (r(0x1A)*240+r(0xFD))
  if previousCamera then cameraMoved=cameraMoved+(horizontal and ((position-previousCamera)%65536) or ((previousCamera-position)%61440)) end
  previousCamera=position
  if horizontal then assert(r(0x723)<=129,'Running camera must prevent screen-X overflow') end
 end
 if f==1100 then
  print('scroll horizontal='..tostring(horizontal)..' updates='..updates..' cameraDelta='..cameraMoved..' localX='..r(0x723)..' localY='..r(0x720)..' visible PPU writes='..#badWrites)
  for _,s in ipairs(badWrites) do print(s) end
  assert(updates>300,'Camera test must keep running')
  assert(cameraMoved>500,'Camera must advance across multiple native pages')
  assert(#badWrites==0,'Graphics streaming must stay outside visible scanlines')
  for _,s in ipairs(lateRendering) do print('Late rendering '..s) end
  assert(#lateRendering==0,'Graphics streaming must restore rendering before prerender scroll reload')
  local tag=horizontal and 'horizontal' or 'vertical'
  local o=assert(io.open((TEST_ROOT..'/build/scroll-')..tag..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
