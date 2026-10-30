local f=0;local stage=0;local seeded=0;local hurt=false;local recovered=false;local down=false;local lying=false;local poses={};local pending=nil;local late=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function playerBounds()
 local top=240;local bottom=-1
 -- Read the displayed nametable and raw MMC2 FE art, not the requested pose.
 -- This ring region contains only the player during ordinary hit recoil.
 for row=12,29 do for col=2,10 do
  local tile=emu.read(0x2000+row*32+col,emu.memType.nesPpuDebug)
  for y=0,7 do
   local a=8192+tile*16+y
   if(emu.read(a,emu.memType.nesChrRom)|emu.read(a+8,emu.memType.nesChrRom))~=0 then
    top=math.min(top,row*8+y);bottom=math.max(bottom,row*8+y)
   end
  end
 end end
 return top,bottom
end
emu.addEventCallback(function()
 local getup=r(5)==2
 setPad(0,{start=f<1800 and f%120<3,a=getup and f%12<2,b=getup and f%12>=6 and f%12<8});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if f<2200 or r(4)~=255 or r(0x50)~=1 or r(5)~=0 or r(0x98)<128 or r(0xb5)==0 then return end
 if stage~=0 and not(stage==2 and recovered and f>seeded+180)then return end
 -- Wait for a real AI punch and its owning opponent script. An isolated
 -- synthetic punch skips the opponent's knockdown/referee handoff.
 local hp=stage==0 and 96 or 1
 w(0x391,hp);w(0x392,hp);w(0x76,0);w(0x77,0)
 stage=stage+1;seeded=f
 print('SEED incoming punch '..stage..' HP '..hp..' at '..f)
end,emu.callbackType.exec,0xa6ba)
emu.addMemoryCallback(function()
 if stage==1 and r(0x391)<96 then
  assert(r(0x391)>0 and r(5)==0,'ordinary native punch must not knock Mario down')
  hurt=true;stage=2
 end
 if stage==3 and r(5)==2 then down=true;stage=4 end
end,emu.callbackType.exec,0xa6bd)
emu.addMemoryCallback(function()
 local n=r(0x61)
 if stage==2 and n>=0x2a and n<=0x35 then
  assert(r(5)==0,'nonlethal recoil remains a standing boxing state');poses[n]=true
  local top,bottom=playerBounds()
  assert(bottom==215 and bottom-top>=29,'displayed ordinary hit must stay upright on the stance floor: '..top..'..'..bottom)
  if not pending then pending='recoil'end
 end
 if n==0x3a then
  assert(r(5)==2,'lying art is reserved for a genuine native knockdown');lying=true;pending='knockdown'
 end
end,emu.callbackType.exec,0xa5ec)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled']then late=late+1 end
end,emu.callbackType.write,0x2006,0x2007)
emu.addEventCallback(function()
 f=f+1
 if pending then local o=assert(io.open(TEST_ROOT..'/build/player-'..pending..'.png','wb'));o:write(emu.takeScreenshot());o:close();pending=nil end
 if stage==2 and hurt and f>seeded+50 and r(0x50)==1 then recovered=true end
 if stage==4 and down and lying and r(5)==0 and r(0x392)>0 and r(0x50)==1 then
  local count=0;for _ in pairs(poses)do count=count+1 end
  assert(count>=2 and recovered,'standing recoil and native recovery are exercised')
  assert(late==0,'damage/recovery transitions retain VRAM deadlines')
  print('PASS native nonlethal hit: '..count..' standing recoil poses; lethal hit: true knockdown, lying pose and successful get-up; zero late writes');emu.stop(0)
 end
 assert(f<10000,'damage fixture must complete; stage '..stage..' pose '..r(0x61)..' state '..r(0x50)..' HP '..r(0x391)..'/'..r(0x392)..' KD '..r(5))
end,emu.eventType.endFrame)
