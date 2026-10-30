local f=0
local checks=0
local expectedGun=dofile(TEST_ROOT..'/tests/rifle-expected.lua')
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 f=f+1
 if f==1350 then assert(checks>200,'Both base players must repeatedly use the supplied back view and forward rifle');print('PASS '..checks..' native base back-view/rifle frames')end
end,emu.eventType.endFrame)
emu.addMemoryCallback(function()
 if f<950 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 for p=0,1 do
  local raw=r(0x6112+p);assert((raw&128)~=0,'Base hallways must display back-facing Mario/Luigi')
  local body=0x6410+p*16;local gun=0x6400+p*8
  if(raw&63)~=22 and(raw&63)~=25 and(r(body)~=0xf8 or r(body+8)~=0xf8)then
   local expected=expectedGun(raw,0,false,r(body+3),r(body),r(body+2))
   if expected.y<239 then
    assert(r(gun)==expected.y and r(gun+1)==expected.tile and r(gun+2)==expected.attr and r(gun+3)==expected.x,'The back-facing player must aim the rifle into the base hallway')
    assert(r(gun+5)==0x8e,'The unused half of a vertical rifle must be transparent')
   end
  end
 end
 checks=checks+1
end,emu.callbackType.write,0x4014)
dofile(TEST_ROOT..'/tests/video.lua')
