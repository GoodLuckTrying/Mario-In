local f=0;local demo=0;local play=0;local draws=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=f>9000 and f%120<3,b=f>11000 and f%40<2});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 draws=draws+1
 if r(4)==0x80 then demo=demo+1 end
 if r(4)==0xff and r(0x50)>0 and r(0x50)<64 then play=play+1 end
end,emu.callbackType.exec,H.RenderMario)
emu.addEventCallback(function()
 f=f+1
 if f==13500 then
  assert(demo>50,'attract demo must render Mario')
  assert(play>50,'Start exits attract mode to a new playable bout')
  print('PASS cold title, attract demo, Start exit and new-game boxing; '..draws..' Mario uploads');emu.stop(0)
 end
end,emu.eventType.endFrame)
