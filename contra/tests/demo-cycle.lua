-- Let all three native attract sequences finish without controller input.
-- The next NMI must not reinterpret a queued terrain block as title text.
local f=0
local lastGame=nil
local completions=0
local active={}
local returning=nil
local titleFrames=0
local done=false
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()setPad(0,{});setPad(1,{})end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 if done then return end
 f=f+1
 local game=r(N.GAME_ROUTINE_INDEX)
 if game==2 and r(N.LEVEL_ROUTINE_INDEX)==4 then active[r(N.CURRENT_LEVEL)]=true end
 if lastGame==2 and game==0 then completions=completions+1;returning=f;titleFrames=0 end
 if returning then
  assert(f-returning<80 or game~=0,'demo must return to the title instead of hanging in its graphics reader')
  if game==1 then titleFrames=titleFrames+1 end
  if titleFrames>=60 then
   print('Completed demo '..completions..' and rendered '..titleFrames..' title frames')
   if completions>=3 then
    assert(active[0] and active[1] and active[2],'all three native demo stages must run')
    print('PASS three complete demo/title cycles with no controller input');done=true;emu.stop(0)
   end
   returning=nil
  end
 end
 lastGame=game
 assert(f<15000,'three native demos must finish and return to the title')
end,emu.eventType.endFrame)
