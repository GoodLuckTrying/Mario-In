dofile(TEST_ROOT..'/tests/common.lua')
local src=assert(io.open(TEST_ROOT..'/build/player-patterns.chr','rb'));local patterns=src:read('*a');src:close()
local weapons=assert(io.open(TEST_ROOT..'/build/source/bin/dat/DemoSpritePatterns.dat','rb'));local weaponPatterns=weapons:read('*a');weapons:close()
local last=nil
local gap=0
local updates=0
local prepared=false
local frames={}
local shots=0
local function blank()
 local s=emu.getState()
 return s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled'])
end
emu.addMemoryCallback(function()
 if first then assert(blank(),'new patterns and palette data are transferred with rendering disabled or in vblank')end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function()
 if not first then return end
 if last then gap=math.max(gap,f-last)end
 last=f;updates=updates+1
 if not prepared then
  prepared=true
  for i=1,12 do w(H.ObjType+i,0);w(H.ObjMetastate+i,0)end
  for i=0,703 do w(0x6530+i,0x26)end
  w(H.ObjX,120);w(H.ObjY,141);w(H.ObjState,0);w(H.ObjGridOffset,0)
  w(H.DoorwayDir,0)
 end
end,emu.callbackType.exec,H.UpdatePlayer)
function input(t)
 if t<30 then return{down=true,a=t%12==2}
 elseif t<60 then return{up=true,a=t%12==2}
 elseif t<90 then return{left=true,a=t%12==2}
 elseif t<120 then return{right=true,a=t%12==2}end
 return{}
end
function tick(t)
 if t<0 then return end
 for i=0,1791 do
  assert(emu.read(i,emu.memType.nesPpuDebug)==patterns:byte(i+1),'actual CHR RAM contains the authored Mario directional poses')
 end
 for i=0,479 do
  assert(emu.read(0x700+i,emu.memType.nesPpuDebug)==weaponPatterns:byte(i+1),'bomb explosions, arrows, sword beams, magic shots and Mario lift art remain correct in CHR RAM')
 end
 local oam=emu.memType.nesSpriteRam
 if t>5 then
  frames[emu.read(73,oam)]=true
  for _,offset in ipairs({0x11,0x12,0x13})do
   local expected=offset==0x11 and 0x30 or offset==0x12 and 0x27 or 0x16
   assert(emu.read(0x3f00+offset,emu.memType.nesPpuDebug)==expected,'actual Fire Mario palette remains white/skin/red and contrasts with sand')
  end
  for i=0x60,0xfc,4 do
   local tile=emu.read(i+1,oam)
   if emu.read(i,oam)<240 and (tile==0x58 or tile==0x5a)then shots=shots+1 end
  end
 end
 if (not LEVEL or LEVEL==0)and(t==25 or t==55 or t==85 or t==115)then screenshot('direction-'..t)end
 if t==150 then
  assert((frames[0x5c]or frames[0x5e])and(frames[0x54]or frames[0x60])and(frames[0]or frames[4]),'front, back and side walking poses all reach hardware OAM')
  assert(shots>20,'animated fireballs reach hardware sprites')
  assert(gap<=2 and updates>140,'new mechanics preserve the native frame cadence')
  finish('native frame cadence, all four Mario poses, Fire palette, projectile OAM and safe PPU timing')
 end
end
