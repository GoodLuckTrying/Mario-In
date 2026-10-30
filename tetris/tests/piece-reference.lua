-- Compare the native piece engine with the original ROM at a fixed seed.
-- Sheltering Mario isolates piece behavior from intentional stomp/death.
local f=0
local first=nil
local trace={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 w(N.rng_seed,0x89);w(N.rng_seed+1,0x88)
end,emu.callbackType.exec,N.gameModeState_initGameState)
emu.addMemoryCallback(function()w(N.player1_startLevel,LEVEL or 0)end,emu.callbackType.exec,N.gameModeState_initGameBackground)
emu.addMemoryCallback(function()
 first=first or f
 if HACK then
  w(0x7801,160);w(0x7802,208);w(0x7805,0);w(0x7806,0);w(0x7820,0)
 end
end,emu.callbackType.exec,N.makePlayer1Active)
emu.addEventCallback(function()
 local t=first and f-first or -1
 setPad(0,{start=r(N.gameMode)<4 and f%90<4,
  left=t>=5 and t<9 or t>=45 and t<49,right=t>=25 and t<29,
  a=t==60 or t==65 or t==85,b=t==70 or t==75 or t==90,down=t>=110 and t<135})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if first and f-first<=180 then
  local row={}
  assert(r(N.player1_levelNumber)==(LEVEL or 0),'exercise the requested gravity speed')
  for _,a in ipairs({N.player1_tetriminoX,N.player1_tetriminoY,N.player1_currentPiece,N.player1_playState,N.player1_fallTimer,N.player1_autorepeatX,N.player1_lines,N.player1_score,N.nextPiece})do row[#row+1]=r(a)end
  for a=0x400,0x4c7 do row[#row+1]=r(a)end
  trace[#trace+1]=table.concat(row,',')
 end
 if first and f-first==180 then
  local file=assert(io.open(TRACE_FILE,'w'));file:write(table.concat(trace,'\n'));file:close()
  assert(#trace>=180,'capture all native engine updates');print('PASS native piece trace '..#trace);emu.stop(0)
 end
 assert(f<1500,'reference piece replay finishes')
end,emu.eventType.endFrame)
