-- A busy controller-driven co-op replay must not turn the game into 30 Hz.
local f=0
local updates=0
local start=nil
local total=0
local maximum=0
local rngUpdates=0
local controlledSnow=(STAGE or 0)==5
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v%256,emu.memType.nesDebug)end
-- The title's sprite-zero wait changes the idle RNG spin count. Snow's
-- previous absolute bound followed one incidental enemy/weather sequence.
-- Compare it with an explicit RNG/frame sequence and no DMC pad double-clock.
-- The pre-title ROM (518ce845...) measures 429/600 on this same fixture.
emu.addMemoryCallback(function()
 if controlledSnow then emu.write(0x4015,0x0f,emu.memType.nesMemory)end
end,emu.callbackType.exec,N.load_controller_state)
emu.addEventCallback(function()
 for p=0,1 do setPad(p,{start=p==0 and (f==120 or f==200 or f==400),select=p==0 and f==180,
 right=f>=950,b=f>=950 and f%8<4,a=f>=950 and (f+p*20)%100<30})end
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<940 then return end
 for p=0,1 do w(0x6004+p*128,2);w(0x6035+p*128,0);w(0x604C+p*128,2);w(0x6049+p*128,240);w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0)end
end,emu.callbackType.exec,N.player_state_routine_01_logic)
emu.addMemoryCallback(function()
 if controlledSnow and f>=480 then
  w(N.RANDOM_NUM,(rngUpdates*37+11)&255);w(N.FRAME_COUNTER,rngUpdates&255);rngUpdates=rngUpdates+1
 end
 if f>=950 and f<1550 then updates=updates+1;start=emu.getState()['cpu.cycleCount']end
end,emu.callbackType.exec,N.exe_game_routine)
emu.addMemoryCallback(function()
 if start then local dt=emu.getState()['cpu.cycleCount']-start;total=total+dt;maximum=math.max(maximum,dt);start=nil end
end,emu.callbackType.exec,N.draw_sprites)
emu.addEventCallback(function()
 f=f+1
 if f==480 and STAGE and STAGE~=0 then w(N.CURRENT_LEVEL,STAGE);w(N.LEVEL_ROUTINE_INDEX,0)end
 if f==1550 then
  print('Co-op performance stage '..(STAGE or 0)..': '..updates..'/600 updates; mean game logic '..math.floor(total/math.max(1,updates))..' CPU cycles; peak '..maximum)
  local minimum=({[0]=380,[1]=510,[5]=429,[6]=340})[STAGE or 0] or 550
  assert(updates>=minimum,'Co-op movement/volleys must retain the measured performance improvement')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
