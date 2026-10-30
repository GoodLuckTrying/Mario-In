dofile(TEST_ROOT..'/tests/common.lua')
-- Use real menu input to select VS and its opponent, without poking mode.
emu.addEventCallback(function()
 if done then return end
 local p1,p2={},{}
 if r(N.gameMode)<4 then
  p1.start=f%90<4
  if r(N.gameMode)==2 then
   local target=r(0x78a1)==0 and 1 or (HUMAN and 1 or 0)
   p1.down=r(0x78a2)~=target and f%30==10
  end
 elseif first then
  if input then p1=input(f-first)or{}end
  if input2 then p2=input2(f-first)or{}end
 end
 setPad(0,p1);setPad(1,p2)
end,emu.eventType.inputPolled)
