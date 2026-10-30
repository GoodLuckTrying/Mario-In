-- Keep the real Jungle terrain and bridge actors. Isolate damage so the
-- full-speed replay exercises actual collapsing sections. SIGNED_EDGE adds a
-- separate native actor-position fixture for sections crossing screen left.
local f=0
local bridgeFrames=0
local updates=0
local bad={}
local maxQueue=0
local moved=0
local pending=nil
local wrapped=0
local checked=0
local start=START or 740
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function issue(s) if #bad<10 then bad[#bad+1]='f'..f..' screen '..r(N.LEVEL_SCREEN_NUMBER)..': '..s end end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=COOP and f==180,right=f>=start,b=f>=start})
 setPad(1,{right=COOP and f>=start,b=COOP and f>=start})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<730 then return end
 for p=0,COOP and 1 or 0 do
  w(0x6004+p*128,POWER or 1);w(0x6035+p*128,0);w(0x604C+p*128,2);w(0x6049+p*128,255)
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if not SIGNED_EDGE or f<730 then return end
 local e=emu.getState()['cpu.x']
 if r(N.ENEMY_TYPE+e)==0x12 and r(N.ENEMY_ROUTINE+e)>1 then
  -- Set a legal screen-left position before the native actor update loads
  -- working state. Keep it on-screen through the explosion delay; its
  -- previous-section tile offset crosses X=0 and must remain signed.
  w(N.ENEMY_X_POS+e,32)
 end
end,emu.callbackType.exec,N.exe_enemy_routine)
local function bridgeUpdate()
 if f<=730 or r(N.CURRENT_LEVEL)~=0 or r(N.ENEMY_TYPE+r(N.ENEMY_CURRENT_SLOT))~=0x12 then return end
 updates=updates+1
 local e=r(N.ENEMY_CURRENT_SLOT);local state=emu.getState()
 local x=state['cpu.a']
 local negative=r(N.ENEMY_X_POS+e)<(r(N.ENEMY_VAR_2+e)==0 and 44 or 12)
 if negative then x=x-256;wrapped=wrapped+1 end
 local world=x+r(N.HORIZONTAL_SCROLL)
 local nt=(r(N.PPUCTRL_SETTINGS)&1)~(math.floor(world/256)&1)
 local y=(state['cpu.y']+r(N.VERTICAL_SCROLL))%240
 pending={address=0x2000+nt*0x400+math.floor(y/8)*32+math.floor((world%256)/8),nt=nt}
end
emu.addMemoryCallback(bridgeUpdate,emu.callbackType.exec,N.load_bank_3_update_nametable_supertile)
if H.BridgeTileGate then emu.addMemoryCallback(bridgeUpdate,emu.callbackType.exec,H.BridgeTileGate) end
emu.addMemoryCallback(function()
 if not pending then return end
 checked=checked+1
 local actual=r(0x12)+r(0x13)*256
 if actual~=pending.address then issue(string.format('Bridge address %04X, expected %04X',actual,pending.address)) end
 if r(0x0D)~=math.floor(pending.address/256) or r(0x15)~=0x23+pending.nt*4 or (r(0x02)&0x40)~=pending.nt*64 then
  issue('Bridge attributes/collision must select the same nametable as its tiles')
 end
 pending=nil
end,emu.callbackType.exec,N.update_nametable_supertile+11)
emu.addMemoryCallback(function()
 if f<740 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then issue('visible VRAM write line '..s['ppu.scanline']..' PC '..string.format('%04X',s['cpu.pc'])) end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function(a,v)
 if f<740 or r(N.LEVEL_ROUTINE_INDEX)~=4 or (v&0x18)==0 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 or s['ppu.scanline']==-1 and s['ppu.cycle']>=256 then
  issue('late rendering restore line '..s['ppu.scanline']..' dot '..s['ppu.cycle'])
 end
end,emu.callbackType.write,0x2001)
emu.addEventCallback(function()
 f=f+1
 if f>740 then
  moved=moved+r(N.FRAME_SCROLL);maxQueue=math.max(maxQueue,r(N.GRAPHICS_BUFFER_OFFSET))
  for s=0,15 do if r(N.ENEMY_ROUTINE+s)>0 and r(N.ENEMY_TYPE+s)==0x12 then bridgeFrames=bridgeFrames+1 end end
 end
 if f==1200 or f==1600 then
  local o=assert(io.open(TEST_ROOT..'/build/bridges-'..(COOP and 'coop-' or 'solo-')..start..'-'..f..'.png','wb'));o:write(emu.takeScreenshot());o:close()
 end
 if f==1900 then
  print('Bridge run: updates='..updates..' active frames='..bridgeFrames..' camera='..moved..' max queue='..maxQueue..' wrapped='..wrapped..' checked='..checked..' errors='..#bad)
  for _,s in ipairs(bad) do print(s) end
  assert(updates>=4 and bridgeFrames>100 and moved>700,'Run across the actual Jungle bridges while they explode')
  assert(checked>=4,'Exercise actual native bridge tile updates')
  if SIGNED_EDGE then assert(wrapped>=2,'Exercise repeated signed screen-left tile updates in the controlled native actor replay')end
  assert(#bad==0,'Bridge tiles and attributes must target their actual world positions and finish within vblank')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
