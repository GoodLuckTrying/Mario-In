-- Keep a native lyre/health pickup active while Mario moves and changes pose.
-- Inspect hardware OAM after each DMA, not just the player renderer's buffer.
local f=0
local seeded=false
local expected=nil
local checked=0
local bad={}
local bonusFrames=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
emu.addEventCallback(function()
 emu.setInput({start=f==120 or f==200,right=f>=620 and f<635,left=f>=650 and f<665,a=f>=680 and f<700},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<600 or seeded then return end
 seeded=true
 w(0x6804,POWER or 1);w(0x682A,0);w(0x728,0);w(0x6835,0)
 for a=0x761,0x7F1,8 do w(a,0) end
 w(0x751,0x81);w(0x750,100);w(0x753,220);w(0x752,BONUS or 0)
 if OWN_ITEM then
  w(0x6830,2);w(0x6831,170);w(0x6832,130);w(0x6833,240);w(0x68AC,255)
 end
end,emu.callbackType.exec,0xCBB6)
emu.addMemoryCallback(function()
 if not seeded or f<602 then return end
 expected={x=r(0x723),y=r(0x720),facing=r(0x680B),native={},item=nil}
 for slot=0x50,0x64,4 do
  local row={};for i=0,3 do row[i+1]=r(0x200+slot+i) end
  if row[1]<240 then expected.native[#expected.native+1]=row end
 end
 if OWN_ITEM then expected.item={x=r(0x6831),y=r(0x6832)} end
end,emu.callbackType.exec,0xEB2E)
emu.addEventCallback(function()
 f=f+1
 if expected then
  local matches=0
  for tile=0,7 do
   local col=tile%2
   if expected.facing==2 then col=1-col end
   local x=(expected.x-4+col*8)%256
   local y=(expected.y-24+math.floor(tile/2)*8)%256
   for slot=0,252,4 do
    local m=emu.memType.nesSpriteRam
    if emu.read(slot,m)==y and emu.read(slot+1,m)==tile and (emu.read(slot+2,m)&3)==0 and emu.read(slot+3,m)==x then matches=matches+1;break end
   end
  end
  if matches~=8 and #bad<5 then bad[#bad+1]='frame '..f..': Mario has '..matches..' of 8 sprite tiles' end
  if expected.item then
   for tile=0,3 do
    local found=false
    for slot=0,252,4 do
     local m=emu.memType.nesSpriteRam
     if emu.read(slot,m)==expected.item.y+math.floor(tile/2)*8 and emu.read(slot+1,m)==12+tile and (emu.read(slot+2,m)&3)==3 and emu.read(slot+3,m)==expected.item.x+(tile%2)*8 then found=true;break end
    end
    if not found and #bad<5 then bad[#bad+1]='frame '..f..': SMB pickup sprite was lost' end
   end
  end
  for _,row in ipairs(expected.native) do
   local found=false
   for slot=0,252,4 do
    local equal=true
    for i=0,3 do if emu.read(slot+i,emu.memType.nesSpriteRam)~=row[i+1] then equal=false end end
    if equal then found=true;break end
   end
   if not found and #bad<5 then bad[#bad+1]='frame '..f..': native pickup sprite was lost' end
  end
  if #expected.native>0 then bonusFrames=bonusFrames+1 end
  checked=checked+1;expected=nil
 end
 if f==630 and CAPTURE then
  local o=assert(io.open(TEST_ROOT..'/build/sprite-ownership-'..CAPTURE..'.png','wb'));o:write(emu.takeScreenshot());o:close()
 end
 if f>=735 then
  print('Sprite ownership frames='..checked..' with native pickup='..bonusFrames..' errors='..#bad)
  for _,s in ipairs(bad) do print(s) end
  assert(checked>=100 and bonusFrames>=100,'Exercise Mario alongside a persistent native pickup')
  assert(#bad==0,'Player and native pickup must retain their own sprite tiles')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
