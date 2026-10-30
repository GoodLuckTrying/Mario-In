local f=0
local stage=STAGE or 0
local checks=0
local bad={}
local poses={{},{}}
local expectedOam=nil
local initialChecks=0
local frames=assert(io.open(TEST_ROOT..'/build/mario-frames.chr','rb')):read('*a')
local fire=assert(io.open(TEST_ROOT..'/build/fire.chr','rb')):read('*a')
local rifles=assert(io.open(TEST_ROOT..'/build/rifles.chr','rb')):read('*a')
local angles=assert(io.open(TEST_ROOT..'/build/angle-rifles.chr','rb')):read('*a')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v%256,emu.memType.nesDebug) end
local function issue(s) if #bad<6 then bad[#bad+1]=f..': '..s end end
emu.addMemoryCallback(function()
 if f>700 then assert(emu.getState()['cpu.x']<2,'Player hooks must preserve the native player index') end
end,emu.callbackType.exec,N.auto_scroll_player)
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180,
  right=f>=1000 and f<1020,left=f>=1050 and f<1070,a=f>=1100 and f<1125,b=f==1200})
 setPad(1,{left=f>=1000 and f<1010,right=f>=1050 and f<1070,a=f>=1150 and f<1175,b=f==1204})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<950 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 for p=0,1 do
  w(N.NEW_LIFE_INVINCIBILITY_TIMER+p,0xF0)
  if f<980 then w(0x6004+p*128,POWER or 1) end
 end
end,emu.callbackType.exec,H.MoveGate)
emu.addMemoryCallback(function()
 if f<950 or r(0x6107)~=0x64 then return end
 expectedOam={};for i=0,31 do expectedOam[i+1]=r(0x6400+i) end
 for p=0,1 do
  local pose=r(0x6112+p)
  if ((pose&128)~=0)~=(r(N.LEVEL_LOCATION_TYPE)==1)then issue('Player view must follow native base/side perspective')end
  if (pose&0x3f)<27 then
   poses[p+1][pose]=true
   for i=0,127 do
    if emu.read(0x280+p*128+i,emu.memType.nesPpuDebug)~=frames:byte(pose*128+i+1) then
     issue('Player '..p..' CHR differs from its uploaded pose '..pose);break
    end
   end
  end
 end
 checks=checks+1
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function(a,v)
 if (v&0x18)==0 or r(N.GAME_ROUTINE_INDEX)~=5 or r(N.LEVEL_ROUTINE_INDEX)<3 then return end
 for p=0,1 do
  local pose=r(0x6112+p)
  if (pose&0x3f)>=27 then issue('Unprepared pose before display');return end
  for i=0,127 do
   if emu.read(0x280+p*128+i,emu.memType.nesPpuDebug)~=frames:byte(pose*128+i+1) then issue('Wrong pose at display enable');return end
  end
 end
 for i=0,31 do
  if emu.read(0x400+i,emu.memType.nesPpuDebug)~=fire:byte(i+1) then issue('Fireball CHR must use its own pair, separate from native guns');break end
 end
 for i=0,#rifles-1 do
  if emu.read(0x680+i,emu.memType.nesPpuDebug)~=rifles:byte(i+1) then issue('Rifle CHR must survive native stage asset loading');break end
 end
 for i=0,511 do
  local addr=(i<256 and 0x420+i or 0x800+i-256)
  if emu.read(addr,emu.memType.nesPpuDebug)~=angles:byte(i+1)then issue('Angled rifle CHR must survive native stage loading');break end
 end
 initialChecks=initialChecks+1
end,emu.callbackType.write,0x2001)
emu.addMemoryCallback(function()
 if f<950 or r(N.LEVEL_ROUTINE_INDEX)~=4 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 then issue('Visible PPU write line '..s['ppu.scanline']) end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if expectedOam then
  for i=0,31 do if emu.read(i,emu.memType.nesSpriteRam)~=expectedOam[i+1] then issue('Player priority sprites did not reach hardware OAM');break end end
  expectedOam=nil
 end
 if f==480 and stage~=0 then w(N.CURRENT_LEVEL,stage);w(N.LEVEL_ROUTINE_INDEX,0) end
 if f==1350 then
  local count={0,0};for p=1,2 do for _ in pairs(poses[p]) do count[p]=count[p]+1 end end
  print('Stage '..stage..' routine '..r(N.LEVEL_ROUTINE_INDEX)..' checks '..checks..' poses '..count[1]..'/'..count[2]..' errors '..#bad)
  for _,v in ipairs(bad) do print(v) end
  assert(r(N.CURRENT_LEVEL)==stage and r(N.LEVEL_ROUTINE_INDEX)==4,'Exercise native stage gameplay')
  assert(r(N.LEVEL_LOCATION_TYPE)==((stage==1 or stage==3) and 1 or 0),'Stage headers must remain intact')
  assert(checks>200 and initialChecks>200 and count[1]>=3 and count[2]>=3,'Both players must repeatedly change poses')
  assert(#bad==0,'Player CHR must upload correctly during vblank')
  local o=assert(io.open(TEST_ROOT..'/build/stage-'..stage..'.png','wb'));o:write(emu.takeScreenshot());o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
