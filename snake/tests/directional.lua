-- Source-exact two-layer pixels through budgeted uploads and atomic DMA.
local source=dofile(TEST_ROOT..'/build/directional-fixtures.lua')
local f=0;local draws=0;local checked=0;local commits=0;local late=0
local seen={{},{}};local selected=false;local uploaded=0
local fixtureStep=0;local held=0
local world=nil
local pixelCache={}
local dirs={1,5,4,6,2,10,8,9}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()
 if f<820 then return end
 if not world then
  world={{},{}}
  for p=0,1 do for a=0x4c3,0x5db,20 do world[p+1][a]=r(a+p)end end
 end
 -- This fixture isolates sprite states. Keep native world actors at their
 -- live spawn so a later death/menu transition cannot intentionally clear
 -- the OAM page while the test is measuring a drawn Mario.
 for p=0,1 do
  for a,v in pairs(world[p+1])do w(a+p,v)end
  w(0x49b+p,p+1);w(0x40d+p,255);w(0x40f+p,0);w(0x409+p,0);w(0x48d+p,0);w(0x3df+p,9)
 end
 w(0xaf,0)
end,emu.callbackType.exec,H.SceneGate)
emu.addMemoryCallback(function()if not selected then w(0xaa,((STAGE or 0)-1)&255);selected=true end end,emu.callbackType.exec,0x82bf)
emu.addEventCallback(function()setPad(0,{start=f>=700 and f<710});setPad(1,{})end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<820 then return end
 local c=fixtureStep
 local pair=(c//40)%9;local d=(c//5)%8;local anim=c%5
 for p=0,1 do
  local power=p==0 and pair%3 or pair//3
  local dir=dirs[(d+p*3)%8+1]
  w(0x49b+p,p+1);w(0x7000+p,power);w(0x7008+p,1);w(0x7020+p,dir)
  w(0x40d+p,0);w(0x3b7+p,64+p*104);w(0x3cb+p,172);w(0x577+p,0)
  w(0x5b3+p,p);w(0x5c7+p,anim==4 and 2 or 255);w(0x16+p,anim>0 and anim<4 and dir or 0)
 end
 w(3,math.max(0,anim-1)*8)
 for slot=2,19 do w(0x49b+slot,0);w(0x5b3+slot,128)end
 draws=draws+1
 held=held+1
end,emu.callbackType.exec,H.DrawScene)
emu.addMemoryCallback(function()
 if f>820 then commits=commits+1 end
end,emu.callbackType.exec,H.CommitDirections)
emu.addMemoryCallback(function(a,v)
 if f>820 then
  local s=emu.getState();assert(s['ppu.scanline']>=241 or s['ppu.scanline']<0,'sprite DMA starts within vblank')
 end
end,emu.callbackType.write,0x4014)
emu.addMemoryCallback(function(a,v)
 if f>820 then
  local s=emu.getState();local pc=s['cpu.pc']
  if pc>=0xb000 and pc<0xc000 then
   assert(s['ppu.scanline']>=241 or s['ppu.scanline']<0,'every streamed CHR byte fits vblank')
   uploaded=uploaded+1
  end
 end
end,emu.callbackType.write,0x2007)
local function pixel(tile,attr,x,y)
 local xx=(attr&64)~=0 and x or 7-x
 local yy=(attr&128)~=0 and 7-y or y
 local data=pixelCache[tile]
 if not data then
  data={};for n=0,15 do data[n+1]=emu.read(tile*16+n,emu.memType.nesPpuDebug)end;pixelCache[tile]=data
 end
 local lo=data[yy+1];local hi=data[yy+9]
 return((lo>>xx)&1)|(((hi>>xx)&1)<<1)
end
emu.addMemoryCallback(function()
 if f<850 or draws==0 or r(0x7094)~=1 then return end
 pixelCache={}
 local s=emu.getState();assert(s['ppu.scanline']>=241 or s['ppu.scanline']<0,'stream/commit and DMA complete within vblank, scan '..s['ppu.scanline']..' step '..r(0x70b4))
 for p=0,1 do if r(0x70bc+p)==1 then
  local id=r(0x70a2+p);local power=r(0x70a4+p);local flip=r(0x70a6+p)~=0;local base=r(0x70ba+p)
  local ref=source[id+1];assert(ref,'valid active source frame');seen[p+1][id]=true
  for cell=0,7 do
   local ca=base+cell*4;local sa=ca+32
   local cy=emu.read(ca,emu.memType.nesSpriteRam);local sy=emu.read(sa,emu.memType.nesSpriteRam)
   local ct=emu.read(ca+1,emu.memType.nesSpriteRam);local st=emu.read(sa+1,emu.memType.nesSpriteRam)
   local cf=emu.read(ca+2,emu.memType.nesSpriteRam);local sf=emu.read(sa+2,emu.memType.nesSpriteRam)
   assert(cf&3==(power==2 and 0 or(p==0 and 0 or 3)) and sf&3==2,'independent original clothing/skin palettes')
   for y=0,7 do for x=0,7 do
    local cv=pixel(ct,cf,x,y);local sv=pixel(st,sf,x,y)
    assert(cv==0 or sv==0,'clothes and skin masks do not overlap')
    local role=0
    if cv~=0 then role=power==2 and(cv==3 and 1 or 3)or(cv==2 and 1 or 3)end
    if sv~=0 then assert(sv==2,'skin pixel index');role=2 end
    local rx=(cell%2)*8+x;if flip then rx=15-rx end
    local ry=(cell//2)*8+y
    local expected=tonumber(ref[ry+1]:sub(rx+1,rx+1))
    assert(role==expected,'exact hardware source pixels P'..p..' frame '..id..' cell '..cell..' pixel '..x..','..y)
    if expected~=0 then assert(cy<240 or sy<240,'nonempty source cell remains visible: step '..fixtureStep..' P'..p..' id '..id..' power '..power..' cell '..cell..' y '..cy..'/'..sy..' stream '..r(0x70b4)..' DMA '..r(0x70c7))end
   end end
  end
  checked=checked+1
 end end
 if held>=14 and r(0x70a2)==r(0x70ae)and r(0x70a3)==r(0x70af)then fixtureStep=fixtureStep+1;held=0 end
end,emu.callbackType.exec,0xff9c)
emu.addEventCallback(function()
 f=f+1;if f==690 then w(0xb7,1)end
 if f==1200 then local o=assert(io.open(TEST_ROOT..'/build/directional-gameplay-'..(STAGE or 0)..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
 if fixtureStep>=360 then
  for p=1,2 do for id=0,74 do assert(seen[p][id],'all 75 frames reach hardware for P'..p..' missing '..id)end end
  assert(checked>5000 and commits>200 and uploaded>20000,'sustained streaming and both-player source checks')
  print('PASS all 75 source frames, both brothers, small/big/Fire colors, eight directions, hardware OAM, atomic CHR commits and vblank deadlines; checks '..checked..' commits '..commits)
  emu.stop(0)
 end
 assert(f<12000,'bounded directional fixture')
end,emu.eventType.endFrame)

