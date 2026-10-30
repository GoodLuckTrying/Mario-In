TYPE_B=true
dofile(TEST_ROOT..'/tests/common.lua')
emu.addMemoryCallback(function()w(N.player1_startHeight,HEIGHT or 0);w(N.startHeight,HEIGHT or 0)end,emu.callbackType.exec,N.gameModeState_initGameBackground)
function tick(age)
 if age<3 then return end
 assert(r(N.gameType)==1,'native B-Type menu remains selectable')
 assert(r(0x780c)==0 and r(0x7801)>=96 and r(0x7801)<=160 and r(0x7802)>=64 and r(0x7802)<=208,'Mario spawns safely inside the B-Type well')
 if age==90 then
  local cells=0
  for i=0,199 do if r(0x400+i)~=0xef then cells=cells+1 end end
  if (HEIGHT or 0)>0 then assert(cells>0 and r(0x7802)<208,'Mario starts above the generated garbage pile')end
  screenshot('b-height-'..(HEIGHT or 0));finish('B-Type height '..(HEIGHT or 0)..' native garbage and safe Mario spawn')
 end
end
