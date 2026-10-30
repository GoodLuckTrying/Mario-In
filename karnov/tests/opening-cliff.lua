-- Controller replay of the actual first-stage ledge; terrain/camera stay native.
local f=0;local began=nil;local lastX=0;local lastY=0;local cameraX=0;local cameraY=0;local supported=0;local updates=0;local peak=144
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=began and f-began or -1;local jump=JUMP or 75
 setPad(0,{start=not began and f>=120 and f%60<2,right=t>=5,b=RUN~=false and t>=5,a=jump>=0 and t>=jump and t<jump+25})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if r(0x10)~=11 then return end
 -- Isolate the reported terrain fall from enemy damage; retain native terrain,
 -- stage loading, controller input, items, camera selection and collision.
 for i=0,5 do w(0x650+i*16,0)end
 if not began then began=f;lastX=r(0x0c);lastY=r(0x0d)end
 local dx=r(0x0c)-lastX;if dx>128 then dx=dx-256 elseif dx< -128 then dx=dx+256 end
 local dy=r(0x0d)-lastY;if dy>120 then dy=dy-240 elseif dy< -120 then dy=dy+240 end
 cameraX=cameraX+dx;cameraY=cameraY+dy;lastX=r(0x0c);lastY=r(0x0d);updates=updates+1
 local worldX=r(0x63)+cameraX;local worldY=r(0x64)+cameraY;peak=math.min(peak,worldY)
 assert(r(0x61)==0,'actual first-stage terrain is selected')
 assert((r(0x62)&31)<25,'first-stage cliff fall must remain alive: jump='..(JUMP or 75)..' x='..worldX..' y='..worldY..' screenY='..r(0x64)..' camera='..r(0xc4)..' phase='..r(0xc5))
 if worldX>=208 and worldY==176 and r(H.M_STATE)==0 then supported=supported+1 else supported=0 end
 assert(updates<380,'opening route must reach the actual lower floor')
end,emu.callbackType.exec,0xf28d)
emu.addEventCallback(function()
 f=f+1
 if supported>=6 then
  print('PASS native opening cliff: jump='..(JUMP or 75)..', run='..tostring(RUN~=false)..', '..(176-peak)..' pixel drop, six supported lower-floor updates');emu.stop(0)
 end
 assert(f<1500,'bounded native opening route')
end,emu.eventType.endFrame)
