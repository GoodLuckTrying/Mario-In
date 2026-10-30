local f=0
local draws=0
local ready=false
local late=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()if r(0x29)==13 then draws=draws+1 end end,emu.callbackType.exec,H.TitleDraw)
emu.addMemoryCallback(function()if r(0x29)==13 then ready=true end end,emu.callbackType.exec,N.title_menu_loop)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled'] then late=late+1 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if ready then
  assert(draws>30,'unskipped prologue reaches rooftop Mario')
  local o=assert(io.open(TEST_ROOT..'/build/menu-title.chr','rb'));local b=o:read('*a');o:close()
  for i=1,#b do assert(emu.read(i-1,emu.memType.nesPpuDebug)==b:byte(i),'full prologue retains Mario CHR')end
  local seen=0
  for x=0,252,4 do if r(0x200+x)<239 and (r(0x203+x)==0xcc or r(0x203+x)==0xd4) and r(0x201+x)<8 then seen=seen+1 end end
  assert(seen>=8,'complete Mario body drawn on rooftop')
  assert(late==0,'full intro/title upload stays within blanking')
  o=assert(io.open(TEST_ROOT..'/build/repaired-full-intro.png','wb'));o:write(emu.takeScreenshot());o:close()
  print('PASS full unskipped prologue, '..draws..' rooftop Mario draws and clean VRAM timing');emu.stop(0)
 end
 assert(f<7000,'full prologue reaches title menu')
end,emu.eventType.endFrame)
