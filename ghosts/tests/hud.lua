local f=0;local entered=nil;local checks=0;local paletteChecks=0;local t=-1
local source=assert(io.open("C:/nes/Ghosts'n Goblins (USA).nes",'rb'));local original=source:read('*a');source:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function private(tile)return(tile>=0x22 and tile<0x2a)or(tile>=0x38 and tile<0x42)end
emu.addEventCallback(function()
 t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,right=t>=100 and t<800,b=t>=80 and t%24<6,a=t>=100 and t%180<80});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f
 -- Retain real enemies, weapons, movement and HUD updates while isolating death.
 w(0x4f0,(r(0x4f0)&0xfe)|0x40)
end,emu.callbackType.exec,0xdae4)
emu.addMemoryCallback(function()
 if not entered then return end
 for tile=0,0x1d do
  if tile<16 or tile==0x1d then
   for i=0,15 do
    local actual=emu.read(tile*16+i,emu.memType.nesPpuDebug)
    assert(actual==original:byte(17+tile*16+i),'native HUD glyph overwritten: tile '..tile..' byte '..i..' frame '..f)
    checks=checks+1
   end
  end
 end
 local page=(r(0x7d57)==1 and 0x7f or r(0xb1))*256
 for i=0,252,4 do
  if r(page+i)<64 and not private(r(page+i+1))then
   local pal=r(page+i+2)&3
   for shade=1,3 do
    assert(emu.read(0x3f10+pal*4+shade,emu.memType.nesPpuDebug)==(r(0x7e20+pal*4+shade)&63),'HUD palette must retain its native colors')
    paletteChecks=paletteChecks+1
   end
  end
 end
end,emu.callbackType.exec,0xc20c)
emu.addEventCallback(function()
 f=f+1
 if entered and f-entered==400 then local o=assert(io.open(TEST_ROOT..'/build/hud-repaired.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if entered and f-entered>=1000 then
  assert(checks>100000 and paletteChecks>1000,'native text and displayed HUD colors are exercised')
  print('PASS HUD: '..checks..' original font bytes and '..paletteChecks..' displayed HUD palette samples while moving, jumping and firing');emu.stop(0)
 end
 assert(f<3000,'HUD replay must complete')
end,emu.eventType.endFrame)
