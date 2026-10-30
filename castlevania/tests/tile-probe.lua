-- Controlled exhaustive packed-byte contacts, never a controller-only clear.
local frame=0
local count=0
local saved=nil
local total=1152
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
local file=assert(io.open(TILE_OUTPUT,'w'))
file:write('case,result\n')
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 then return end
 w(0x6001,2);w(0x600d,90);w(0x45,64)
 if not NATIVE_TILE then
  w(0x6020,1);w(0x6021,0);w(0x6022,80);w(0x6024,100);w(0x6026,0);w(0x6050,0);w(0x6028,0);w(0x602a,0);w(0x602c,50)
 end
 for x=3,27 do w(0x434+x,0);w(0x60a0+x,0) end
end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if frame<700 or (NATIVE_TILE and r(0x604b)~=1) then return end
 assert(saved==nil,'Tile probe must not recurse')
 saved={}
 for _,a in ipairs({0x28,0x2e,0x2f,0x6052,0x6053,0x10,0x11,0x12,0x13}) do saved[a]=r(a) end
 local n=count
 local stage=n%18
 local camera=n%2==0 and 200 or 3
 local page=n%6
 local byte=math.floor(n/4)%256
 local quarter=n%4
 local world=(byte%8)*32+quarter*8+byte%8
 local x=(world-camera)%256
 local y=48+8*(math.floor(n/8)%22)+n%8
 if n>=1024 then local k=n-1024;y=k<64 and k%48 or 224+k%32 end
 local high=page+math.floor((camera+x)/256)
 w(0x28,stage);w(0x2e,camera);w(0x2f,page);w(0x6052,x);w(0x6053,y)
 if NATIVE_TILE then w(0x10,y);w(0x11,0);w(0x12,world);w(0x13,high) end
 if y>=48 and y<224 then
  local base=(high+r(0xfbd6+stage))%2==0 and 0x5a0 or 0x650
  local address=base+y-y%8-48+math.floor(world/32)
  saved[address]=r(address);w(address,byte)
 end
end,emu.callbackType.exec,TILE_ENTRY)
emu.addMemoryCallback(function()
 if not saved then return end
 local actual=emu.getState()['cpu.a']
 local n=count
 local expected=n<1024 and math.floor((math.floor(n/4)%256)/2^((3-n%4)*2))%4 or 0
 assert(actual==expected,'Native packed tile case '..n..': '..actual..' expected '..expected)
 file:write(n..','..actual..'\n')
 for a,v in pairs(saved) do w(a,v) end
 saved=nil;count=count+1
 if count==total then file:close();print('All '..total..' native packed tile cases passed');emu.stop(0) end
end,emu.callbackType.exec,TILE_EXIT)
emu.addEventCallback(function() frame=frame+1;if frame==2200 then print('FAIL missing packed tile cases '..count);file:close();emu.stop(1) end end,emu.eventType.endFrame)
