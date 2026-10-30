TYPE_B=true
dofile(TEST_ROOT..'/tests/common.lua')
local seeded=nil
local ending=false
emu.addMemoryCallback(function()
 if first and f-first>=20 and not seeded then
  seeded=f
  for i=0,199 do w(0x400+i,0xef)end
  for x=0,9 do if x<3 or x>6 then w(0x400+190+x,0x7b)end end
  w(0x7801,100);w(0x7802,200)
  w(N.currentPiece,18);w(N.tetriminoX,5);w(N.tetriminoY,19);w(N.playState,2);w(N.vramRow,0x20)
  w(N.lines,1);w(N.lines+1,0)
 end
end,emu.callbackType.exec,H.UpdateGate)
function tick(age)
 if not seeded then return end
 if r(N.renderMode)==4 then ending=true end
 if ending and f-seeded>250 then
  assert(r(0x78f1)<=2 and r(0x78f2)==r(0x78f1),'native ending sprite banks must be restored')
  screenshot('b-ending');finish('native B-Type completion and restored ending graphics')
 end
 assert(f-seeded<1500,'B-Type goal must reach its native ending')
end
