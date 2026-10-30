dofile(TEST_ROOT..'/tests/graphics_oracle.lua')
local f=0
local entered=nil
local t=0
local updates=0
local minimum=255
local firing={}
local own=0
local walks={}
local draws=0
local chrChecks=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local weaponFrames={0x40,0x42,0x44,0x36,0x4f}
local function save(name)local o=assert(io.open(TEST_ROOT..'/build/gameplay-'..name..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
emu.addEventCallback(function()
 t=entered and f-entered or -1
 setPad(0,{start=not entered and f>=120 and f%120<3,a=t>=80 and t<160,b=t>=250 and t%24<9,right=t>=730 and t<900,left=t>=910 and t<1000,down=t>=250 and t<300})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 entered=entered or f;updates=updates+1
 for i=1,16 do w(0x4f0+i,0)end
 w(0x4f0,r(0x4f0)&0xfe)
 if t>=250 and t<700 then
  local k=math.floor((t-250)/90)+1
  w(0x53a,weaponFrames[k])
 end
end,emu.callbackType.exec,H.Step)
emu.addMemoryCallback(function()
 if not entered then return end
 draws=draws+1
 assert(r(0x29)==r(0x7d37) and r(0x2a)==4,'only the recorded player command uses Mario graphics')
 local pose=r(H.M_ART_POSE)
 walks[pose]=true
 if r(H.M_ART_READY)==1 and r(H.M_ART_PHASE)==0 then
  local ppu=r(H.BodyTiles+r(H.M_ACTIVE))*16
  for i=0,127 do assert(emu.read(ppu+i,emu.memType.nesPpuDebug)==r(0x7000+pose*128+i),'committed Mario frame matches source CHR')end
  chrChecks=chrChecks+1
 end
end,emu.callbackType.exec,H.DrawMario)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2000,'gameplay enters');return end
 t=f-entered
 if t>=80 and t<=200 then minimum=math.min(minimum,r(0x599))end
 for i=17,19 do if r(0x4f0+i)~=0 then firing[r(0x631+i)]=true end end
 if r(H.FB)>0 then own=own+1 end
 if t==140 or t==280 or t==500 or t==850 then save(t)end
 if t==298 then assert(r(H.M_DUCK)==1,'Down produces big Mario crouch; state '..r(H.M_STATE)..' held '..r(H.M_HELD)..' native '..r(H.M_NATIVE)..' y '..r(0x599))end
 if t==315 then assert(r(H.M_DUCK)==0,'releasing Down stands up')end
 if t==1010 then
  assert(minimum<=120 and minimum>=118,'held jump reaches the SMB1 64-pixel apex, got '..minimum)
  for k=0x23,0x27 do assert(firing[k],'native weapon type '..k..' still spawns')end
  assert(own>40 and draws>200 and chrChecks>100,'private fireballs and stable Mario art are exercised')
  assert(walks[0] and walks[1] and walks[2] and walks[4] and walks[10],'walk, jump and crouch frames exercised')
  print('PASS native boot and opening, held jump apex '..minimum..', crouch, five native weapons plus fireballs; '..chrChecks..' CHR checks');assertMarioGraphics();emu.stop(0)
 end
 assert(t<1050,'bounded gameplay fixture')
end,emu.eventType.endFrame)
