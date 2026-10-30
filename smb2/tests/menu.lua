dofile(TEST_ROOT..'/tests/common.lua')
local changed=0
local old=nil
emu.addEventCallback(function()
 if not menu or first or done then return end
 local t=f-menu
 setPad(0,{right=t>=10 and t<100 and t%10==0,left=t>=100 and t<200 and t%10==0,a=t==220})
end,emu.eventType.inputPolled)
function tick(t)
 if menu and not first then
  local id=r(H.CurrentCharacter)
  assert(id==0 or id==3,'menu never selects Princess or Toad')
  if old and id~=old then changed=changed+1 end
  old=id
  if f-menu==180 then
   for _,offset in ipairs({0x30,0x34,0x38,0x3c,0x40,0x44,0x48,0x4c})do assert(r(0x200+offset)==0xf8,'third and fourth portraits are hidden')end
   screenshot('two-character-menu')
  end
 end
 if t>5 then
  assert(changed>=12,'both D-pad directions repeatedly cycle only the two brothers')
  assert(r(H.CurrentCharacter)==old,'selected brother persists into gameplay')
  finish('only Mario/Luigi, repeated left/right wrapping, hidden third/fourth portraits and confirmation')
 end
end
