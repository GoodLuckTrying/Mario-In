dofile(TEST_ROOT..'/tests/common.lua')
local seen={};local captured={}
function tick(t)
 if mode()==0x87DB then
  local i=r(0x6d);if r(0x12b)~=255 then assert(i<2,'only Mario and Luigi are selectable by humans');seen[i]=true end
  if r(0x18)&127==1 and not captured[i]then screen('selection-'..i);captured[i]=true end
 end
 if first then
  assert(seen[0]and seen[1],'real controller carousel visited both brothers')
  for i=0,r(0x100)-1 do assert(r(0x125+i)<2,'all human participants use Mario/Luigi')end
  if MODE==7 then assert(r(0x100)==6,'original six-player tournament retained with repeated brothers')end
  finish('controller character selection, portraits/names, only two selectable identities and valid tournament roster')
 end
end
