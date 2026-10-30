local f=0;local previous=nil;local changes=0;local reached={};local transitions=0;local pending=false;local displayMode=0;local display={0,0};local references={}
local function r(a)return emu.read(a,emu.memType.nesDebug)end
for i=0,4 do local file=assert(io.open(TEST_ROOT..'/build/title-expected-'..i..'.rgb','rb'));references[i]=file:read('*a');file:close()end
emu.addEventCallback(function()
 local choose=COOP and r(N.GAME_ROUTINE_INDEX)==1 and r(N.HORIZONTAL_SCROLL)==0 and r(N.PLAYER_MODE)==0
 setPad(0,{select=choose});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()display={r(0x7927),r(0x7928)};displayMode=r(0x6404)==167 and 1 or 0 end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1;local game=r(N.GAME_ROUTINE_INDEX)
 if game~=previous then print('TRANSITION f '..f..' game '..game..' level '..r(N.LEVEL_ROUTINE_INDEX)..' title '..r(0x7920)..' ppu '..r(N.PPU_READY));previous=game end
 -- The native timer decrements its high byte when the low byte reaches
 -- zero, rather than on underflow. Its final countdown has high byte 1.
 if f>50 and r(0x7920)==1 and r(N.PPU_READY)==0 and(game==2 or r(N.DELAY_TIME_HIGH_BYTE)<=1 and r(N.DELAY_TIME_LOW_BYTE)<12)then
  local fb=emu.getScreenBuffer();local bad=0;local first=nil
  for y=0,239 do for x=0,255 do
   local rx,ry=x,y
   if displayMode==1 and x>=16 and x<24 then if y>=152 and y<168 then rx,ry=0,0 elseif y>=168 and y<184 then ry=y-16 end end
   local eye=x<200 and display[1]or display[2];local ref=references[eye==0 and 0 or x<200 and eye or eye+2]
   local at=(ry*256+rx)*3+1;local expected=(ref:byte(at)<<16)|(ref:byte(at+1)<<8)|ref:byte(at+2)
   if (fb[y*256+x+1]&0xffffff)~=expected then bad=bad+1;first=first or x..','..y end
  end end
  if bad>0 then
   print('FAIL scrambled title-to-demo frame '..f..' game '..game..' init '..r(N.GAME_ROUTINE_INIT_FLAG)..' level '..r(N.LEVEL_ROUTINE_INDEX)..' pixels '..bad..' first '..first)
   local out=assert(io.open(TEST_ROOT..'/build/title-demo-transition-failure.png','wb'));out:write(emu.takeScreenshot());out:close();emu.stop(1);return
  end
  changes=changes+1
 end
 if game==2 and r(N.LEVEL_ROUTINE_INDEX)==0 then pending=true end
 if game==2 and r(N.LEVEL_ROUTINE_INDEX)==4 and not reached[r(N.CURRENT_LEVEL)]then
  assert(r(N.PLAYER_MODE)==(COOP and 1 or 0),'keep the chosen title cursor mode through the demo handoff')
  assert(pending,'observe the actual title/demo handoff');pending=false
  reached[r(N.CURRENT_LEVEL)]=true;transitions=transitions+1
  print('Clean title-to-demo transition '..transitions..', stage '..r(N.CURRENT_LEVEL)..', full frames checked '..changes)
 end
 if reached[0]and reached[1]and reached[2]then
  assert(changes>=30 and transitions==3,'check every final visible title frame in all three native attract entries')
  print('PASS '..changes..' complete final title frames across all three natural title-to-demo transitions; native demos playable');emu.stop(0)
 end
 assert(f<15000,'all three title/demo transitions must complete')
end,emu.eventType.endFrame)
