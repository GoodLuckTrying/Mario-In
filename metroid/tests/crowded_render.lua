local f=0
local entered=nil
local seeded=nil
local seen={}
local mellow=0
local collisions=0
local hero=0
local maxEnemies=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,b=t>=65 and t%13<2,a=t>=150 and t<175});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x1e)~=3 then return end
 entered=entered or f
 w(0x106,0);w(0x107,9);w(0x70,20)
 if seeded or f-entered<50 then return end
 local source=nil
 for x=16,80,16 do if r(0x6af4+x)==2 and r(0x6b02+x)==5 then source=x;break end end
 if not source then return end
 local en={};local extra={}
 for i=0,15 do en[i]=r(0x400+source+i);extra[i]=r(0x6af4+source+i)end
 for x=16,80,16 do
  for i=0,15 do w(0x400+x+i,en[i]);w(0x6af4+x+i,extra[i])end
  w(0x401+x,16+x*2);w(0x400+x,184);w(0x40a+x,0)
 end
 w(N.EnMellowHandlerExtra_status,2)
 w(N.EnMellowHandlerExtra_resetAnimIndex,r(N.AreaMellowAnimIndex))
 w(N.EnMellowHandlerExtra_animIndex,r(N.AreaMellowAnimIndex))
 w(N.EnMellowHandlerExtra_animDelay,0)
 for i=0,3 do
  local a=N.Mellows_0+i*8
  w(a,1);w(a+1,80+i*12);w(a+2,32+i*55);w(a+3,r(0x30c));w(a+6,0)
 end
 seeded=f
end,emu.callbackType.exec,N.UpdateWorld)
emu.addMemoryCallback(function()
 if not seeded then return end
 local x=r(N.PageIndex)
 seen[x]=true
 if x==0xF0 then mellow=mellow+1 end
 if x==0x50 and r(0x350)==1 then collisions=collisions+1 end
end,emu.callbackType.exec,N.DrawEnemy)
emu.addMemoryCallback(function()
 if not seeded then return end
 hero=hero+1
 assert(r(N.IsSamus)~=0 or(r(N.MainRoutine)==8 and r(N.PageIndex)==0),'enemy draw must never select Mario')
end,emu.callbackType.exec,H.DrawMario)
emu.addEventCallback(function()
 f=f+1
 if seeded then
  local active=0
  for x=16,80,16 do if r(0x6af4+x)~=0 then active=active+1 end end
  maxEnemies=math.max(maxEnemies,active)
  assert(r(H.M_DRAW_FIRE)==0,'private fireball draw context is released')
  if f-seeded==100 then local o=assert(io.open(TEST_ROOT..'/build/crowded-render.png','wb'));o:write(emu.takeScreenshot());o:close()end
  if f-seeded==200 then
   for x=16,80,16 do assert(seen[x],'native enemy render slot '..x..' exercised')end
   assert(mellow>100 and collisions>0,'Mellow handler and live overlapping fireball/enemy slot exercised')
   assert(maxEnemies>=5 and hero>100,'five-enemy fixture and real Mario renderer continue')
   print('PASS five native enemies plus Mellows, all five regular slots and the Mellow handler and overlapping live fireball slot; Mario draws '..hero)
   emu.stop(0)
  end
 end
 assert(f<2000,'crowded native renderer fixture completes')
end,emu.eventType.endFrame)
