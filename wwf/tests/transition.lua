dofile(TEST_ROOT..'/tests/common.lua')
local seeded=false;local result=false;local nativeEnding=false;local winnerChecked=false
function input(t)if result then return{start=t%30==2}end;return{}end
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end
if first then nativeEnding=true end end,emu.callbackType.exec,0xAE62)
emu.addMemoryCallback(function()
 if r(0xc)~=0 then return end

 if not seeded then return end
 local winner=emu.getState()['cpu.x']
 assert(winner==r(WIN==false and 0x130 or 0x12f),'native results name the correct winner')
 winnerChecked=true
end,emu.callbackType.exec,0xB385)
function tick(t)
 if t<0 then return end
 if t==150 then
  -- Last native referee count: no custom win/loss or menu replacement.
  seeded=true;w(0x79,WIN==false and 0 or 200);w(0x7a,WIN==false and 200 or 0)
  w(0xa2,WIN==false and 0 or 255);w(0xa3,WIN==false and 255 or 0)
  w(0xcb,WIN==false and 1 or 0);w(0xcc,WIN==false and 0 or 1)
  w(0x9f,45);w(0xa0,1);w(0xa1,3);w(0x93,255)
 end
 if mode()==0xB42D then result=true;screen(WIN==false and 'result-loss' or 'result-win')end
 if result and mode()~=0xB42D and mode()~=0xB249 then assert(nativeEnding and winnerChecked,'native count ending and correct result winner were executed');finish('native referee pin result, correct winner, victory/loss screen, music/menu and restart transition')end
 assert(t<2000,'pin result and exit complete')
end
