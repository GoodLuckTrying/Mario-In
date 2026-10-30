-- Real independent title timers, all supplied eye states and safe hardware output.
local f=0;local displayed={0,0};local references={};local seen={{},{}}
local checks=0;local independent=0;local transitions={0,0};local previous={0,0}
local writes=0;local rendering=false;local samples={}
local synchronized=false;local simultaneousFrames=0
local displayedMode=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
for i=0,4 do local file=assert(io.open(TEST_ROOT..'/build/title-expected-'..i..'.rgb','rb'));references[i]=file:read('*a');file:close()end
emu.addEventCallback(function()
 -- Select refreshes the native menu timeout and exercises both cursor rows.
 setPad(0,{start=f==120,select=f==180 or f==360 or f==540});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function(a,v)
 rendering=(v&0x18)~=0
 if f>=50 and f<=600 and r(0x7920)==1 and r(N.PPU_READY)==0 then
  local scan=emu.getState()['ppu.scanline']
  assert(scan>=240 or scan<0,'blinking must not blank/unblank the visible title')
 end
end,emu.callbackType.write,0x2001)
emu.addMemoryCallback(function()
 -- A separate stress replay aligns the two valid timers to exercise both
 -- native background commands in the same vblank; normal replay is untouched.
 if SIMULTANEOUS and not synchronized and f>=300 then
  for p=0,1 do
   emu.write(0x7921+p,1,emu.memType.nesDebug)
   emu.write(0x7923+p,0,emu.memType.nesDebug)
  end
  synchronized=true
 end
end,emu.callbackType.exec,H.TitleBlinkGate)
emu.addMemoryCallback(function()
 if r(0x7920)==1 and r(N.PPU_READY)==0 then
  local state=emu.getState();local scan=state['ppu.scanline']
  assert(not rendering or scan>=240 or scan<0,'title eye writes must remain in vblank or forced blank, got '..scan)
  writes=writes+1
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function()
 displayed={r(0x7927),r(0x7928)}
 displayedMode=r(0x6404)==167 and 1 or 0
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1
 if f>=50 and f<=600 then
  assert(r(N.GAME_ROUTINE_INDEX)==1 and r(0x7920)==1,'title remains interactive during independent blinks')
  local changed=false
  for p=1,2 do
   seen[p][displayed[p]]=true
   if displayed[p]~=previous[p]then transitions[p]=transitions[p]+1;changed=true end
  end
  if displayed[1]~=displayed[2]then independent=independent+1 end
  if displayed[1]==displayed[2]and displayed[1]~=0 then simultaneousFrames=simultaneousFrames+1 end
  if changed or f%60==0 then
   local fb=emu.getScreenBuffer();local mode=displayedMode
   for y=0,239 do for x=0,255 do
    local rx,ry=x,y
    if mode==1 and x>=16 and x<24 then
     if y>=152 and y<168 then rx,ry=0,0
     elseif y>=168 and y<184 then ry=y-16 end
    end
    local eye=x<200 and displayed[1]or displayed[2]
    local reference=references[eye==0 and 0 or x<200 and eye or eye+2]
    local at=(ry*256+rx)*3+1
    local expected=(reference:byte(at)<<16)|(reference:byte(at+1)<<8)|reference:byte(at+2)
    assert((fb[y*256+x+1]&0xffffff)==expected,'title blink '..displayed[1]..'/'..displayed[2]..' frame '..f..' pixel '..x..','..y)
   end end
   checks=checks+1
   local key=displayed[1]..'-'..displayed[2]
   if not samples[key]then
    local file=assert(io.open(TEST_ROOT..'/build/title-blink-'..key..'.png','wb'));file:write(emu.takeScreenshot());file:close();samples[key]=true
   end
  end
  previous={displayed[1],displayed[2]}
 end
 if f==601 then
  for p=1,2 do assert(seen[p][0]and seen[p][1]and seen[p][2]and transitions[p]>=12,'both brothers must complete independent double blinks')end
  assert(independent>(SIMULTANEOUS and 40 or 60)and checks>=25 and writes>30,'exercise asynchronous eyes/complete frames/PPU writes: '..independent..'/'..checks..'/'..writes)
  if SIMULTANEOUS then assert(synchronized and simultaneousFrames>=20,'also render both queued eye changes together without overflow')end
  print('PASS '..checks..' complete animated title frames, '..independent..' asynchronous frames, '..transitions[1]..'/'..transitions[2]..' eye transitions, vblank-only eye writes')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
