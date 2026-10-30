local f=0
local checked=0
local visible={0,0}
local frames=assert(io.open(TEST_ROOT..'/build/mario-frames.chr','rb')):read('*a')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function() setPad(0,{});setPad(1,{}) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(a,v)
 if r(N.GAME_ROUTINE_INDEX)~=2 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 checked=checked+1
 for p=0,1 do
  if r(N.P1_GAME_OVER_STATUS+p)==0 and r(N.PLAYER_STATE+p)>0 then
   local found=false
   for i=16+p*16,16+p*16+12,4 do if r(0x6400+i)<240 then found=true end end
   if found and v==0x64 then
    local pose=r(0x6112+p)
    if (pose&0x3f)<27 then
     for i=0,127 do assert(emu.read(0x280+p*128+i,emu.memType.nesPpuDebug)==frames:byte(pose*128+i+1),'Demo pose CHR must be prepared') end
     visible[p+1]=visible[p+1]+1
    end
   end
  end
 end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1
 if f==2500 then
  print('demo checks '..checked..' visible '..visible[1]..','..visible[2])
  assert(checked>100 and visible[1]>80 and visible[2]>80,'Both attract-mode players must be visible as Mario/Luigi')
  local o=assert(io.open(TEST_ROOT..'/build/demo.png','wb'));o:write(emu.takeScreenshot());o:close()
  print('PASS demo visibility');emu.stop(0)
 end
end,emu.eventType.endFrame)
