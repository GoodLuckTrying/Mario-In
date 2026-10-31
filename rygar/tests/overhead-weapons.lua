-- Real overhead entry and native Diskarmor attack, including rotating OAM slots.
local f=0;local began=nil;local moved=false;local drawing=false;local pending={};local drawn={};local sampled={};local artChecks=0;local live=0;local pair=0;local tiles={}
local file=assert(io.open('C:/nes/Rygar (USA).nes','rb'));local base=file:read('*a');file:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=began and f-began or -1;local k=t//80%4;local phase=t%80
 setPad(0,{start=not began and f>=120 and f%60<2,right=t>=0 and k==0 and phase<3,down=t>=0 and k==1 and phase<3,left=t>=0 and k==2 and phase<3,up=t>=0 and k==3 and phase<3,b=t>=0 and(phase==5 or phase==14)})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not moved and f>=280 then moved=true;w(0x1d,0);w(0x301,6);w(0x41,0)end
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
end,emu.callbackType.exec,0x9b9a)
emu.addMemoryCallback(function()
 for i=0,13 do w(0x494+i,0);w(0x5be+i,0)end
 if f>=400 then began=began or f end
end,emu.callbackType.exec,0x9c20)
emu.addMemoryCallback(function()
 if not began then return end
 if r(H.FB)>0 or r(H.FB+16)>0 then live=live+1 end
 if r(H.FB)>0 and r(H.FB+16)>0 then pair=pair+1 end
end,emu.callbackType.exec,0x9c7b)
emu.addMemoryCallback(function()drawing=true;pending={}end,emu.callbackType.exec,0xc14a)
emu.addMemoryCallback(function()
 if drawing and began and r(0x09)==1 and r(0x4a3)==3 and r(0x493)&0x80~=0 and r(0x563)>=5 and r(0x563)<=18 then
  local s=emu.getState();pending[#pending+1]={index=s['cpu.x'],tile=s['cpu.a']}
 end
end,emu.callbackType.exec,0x80ef)
emu.addMemoryCallback(function()drawing=false;drawn=pending end,emu.callbackType.exec,0xc14d)
emu.addMemoryCallback(function()sampled=drawn end,emu.callbackType.write,0x4014)
emu.addEventCallback(function()
 f=f+1
 if not SKIP_ART and began and emu.getState()['ppu.mask.spritesEnabled']then
  for _,cell in ipairs(sampled)do
   local tile=emu.read(cell.index+1,emu.memType.nesSpriteRam)
   assert(tile==cell.tile,'custom OAM preserves the native weapon cell')
   for i=0,31 do
    local expected=base:byte(16+2*16384+0x800+tile*16+i+1)
    assert(emu.read(tile*16+i,emu.memType.nesPpuDebug)==expected,'displayed native overhead Diskarmor CHR: tile '..tile..' byte '..i)
   end
   tiles[tile]=true;artChecks=artChecks+1
  end
 end
 if began and f-began>=335 then
  assert(live>=15,'overhead B throws persistent fireballs: '..live)
  assert(pair>=2,'both independent overhead fireballs coexist: '..pair)
  if not SKIP_ART then assert(artChecks>80 and tiles[0x0a]and tiles[0x12]and tiles[0x1e],'horizontal and vertical native weapon frames exercised')end
  print('PASS overhead B: '..live..' live-shot updates, '..pair..' paired updates, '..artChecks..' native hardware weapon cells intact');emu.stop(0)
 end
 assert(f<1600,'bounded overhead weapon replay')
end,emu.eventType.endFrame)
