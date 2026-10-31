-- Stage a native grapple/rope attachment and provide its native contact query.
-- The native action/velocity/animation state machine owns subsequent movement.
local f=0;local began=nil;local rope=0;local minY=255;local afterUp=nil;local afterDown=nil;local poses={};local sampled=nil
local file=assert(io.open(TEST_ROOT..'/build/directional-frames.bin','rb'));local art=file:read('*a');file:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=began and f-began or -1
 setPad(0,{start=not began and f>=120 and f%60<2,up=t>=0 and t<45,down=t>=45 and t<90})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
end,emu.callbackType.exec,0x9b9a)
emu.addMemoryCallback(function()
 if not began then
  if f<350 then return end
  began=f
  w(0xc0,r(0xc0)|0x80);w(0x492,0x84);w(0x4b2,0xa8)
  w(0x4c2,0xe0);w(0x4d2,0);w(0x4e2,0);w(0x4f2,140);w(0x502,0);w(0x512,96)
  w(0x610,0);w(0x611,140)
 end
 w(0x612,0x81)
end,emu.callbackType.exec,0x9bc1)
emu.addMemoryCallback(function()
 if not began then return end
 if r(0x492)&4~=0 then
  assert(r(0x7d31)==0,'native rope/grappling state must bypass SMB integration')
  rope=rope+1;minY=math.min(minY,r(0x4f2))
 end
 local t=f-began
 if t==44 then afterUp=r(0x4f2)end
 if t==89 then afterDown=r(0x4f2)end
end,emu.callbackType.exec,0x9bc4)
emu.addMemoryCallback(function()
 sampled=nil
 if began and r(0x7d74)~=0 and r(0x7d6e)~=0 then sampled={frame=r(0x7d6c),buffer=r(0x7d6f)}end
end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1
 if sampled and emu.getState()['ppu.mask.spritesEnabled']then
  for cell=0,3 do
   local tile=emu.read(17+cell*4,emu.memType.nesSpriteRam)
   assert(tile==sampled.buffer+cell*2,'hardware OAM uses the committed climb frame')
   for i=0,31 do assert(emu.read(tile*16+i,emu.memType.nesPpuDebug)==art:byte(sampled.frame*128+cell*32+i+1),'complete hardware climb CHR')end
  end
  poses[sampled.frame]=true
 end
 if began and f-began>=110 then
  assert(rope>=70,'sustained native rope movement exercised: '..rope)
  assert(afterUp and afterUp<130,'Up climbs the rope: '..tostring(afterUp))
  assert(afterDown and afterDown>afterUp+10,'Down descends the rope: '..tostring(afterDown))
  assert(poses[20]and poses[21],'both climbing frames displayed')
  print('PASS native rope controls up/down and two committed climbing frames, '..rope..' updates');emu.stop(0)
 end
 assert(f<1500,'bounded rope fixture')
end,emu.eventType.endFrame)
