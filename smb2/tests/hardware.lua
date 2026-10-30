dofile(TEST_ROOT..'/tests/common.lua')
local lastbank=nil
local command=0
local updates=0
local last=nil
local maxgap=0
local banks=0
emu.addMemoryCallback(function()
 if not first or f-first<130 then return end
 updates=updates+1
 if last then maxgap=math.max(maxgap,f-last)end
 last=f
end,emu.callbackType.exec,H.HandlePlayerState)
emu.addMemoryCallback(function()lastbank=r(H.SpriteCHR1)end,emu.callbackType.exec,H.ChangeCHRBanks)
local function blank()
 local s=emu.getState()
 return s['ppu.scanline']<0 or s['ppu.scanline']>=240 or not(s['ppu.mask.backgroundEnabled']or s['ppu.mask.spritesEnabled'])
end
emu.addMemoryCallback(function(a,v)command=v&7 end,emu.callbackType.write,0x8000)
emu.addMemoryCallback(function()
 if first and f-first>5 and command<6 then assert(blank(),'MMC3 CHR changes stay in vblank or forced blank')end
end,emu.callbackType.write,0x8001)
emu.addMemoryCallback(function()
 if first and f-first>5 then assert(blank(),'PPU data writes stay in vblank or forced blank')end
end,emu.callbackType.write,0x2007)
local source=assert(io.open(TEST_ROOT..'/dist/SMB1 Mario and Luigi in Super Mario Bros 2.nes','rb'))
local rom=source:read('*a');source:close()
local function ppu(a)return emu.read(a,emu.memType.nesPpuDebug)end
local prepared=false
emu.addMemoryCallback(function()
 if not first or f-first<130 then return end
 if SMALL and not prepared then
  w(H.PlayerHealth,15);w(H.PlayerCurrentSize,1);prepared=true
 end
end,emu.callbackType.exec,H.HandlePlayerState)
function input(t)return{a=t>=150 and t<175,b=t%20<5,right=t>=145 and t<165}end
function tick(t)
 -- Native room/camera scroll sequences deliberately suspend control.
 if r(H.NeedsScroll)~=0 or r(H.PlayerLock)~=0 then last=nil end
 if t<15 then return end
 if lastbank and lastbank>=128 and lastbank<154 then
  for i=0,191 do
   local expected=rom:byte(0x20010+lastbank*1024+i+1)
   assert(ppu(i)==expected,'hardware sprite pattern bank contains the selected SMB1 pose and fireball art')
  end
  banks=banks+1
 end
 if t==260 then
  assert(banks>100,'native vblank transfers actually select the SMB pose banks')
  local color=(CHAR==3)and{SMALL and 0x30 or 0x37,0x27,0x19}or(SMALL and{0x16,0x27,0x18}or{0x37,0x27,0x16})
  for i=1,3 do assert(ppu(0x3f10+i)==color[i],'hardware palette matches big Fire or Small SMB colors')end
  assert(maxgap<=2,'new controls and fireballs do not stall the native frame loop: '..maxgap)
  screenshot('hardware-'..(WORLD or 0)..'-'..(CHAR or 0)..'-'..tostring(SMALL))
  finish('world opening, native streaming, SMB CHR/palette, vblank transfers and frame budget')
 end
end
