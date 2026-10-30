-- Moving/shooting replay with native enemies, mapper and visible-PPU guards.
local mm=GAME=='megaman2'
local f=0
local entered=nil
local updates=0
local ticks=0
local lateWrites=0
local badMapper=0
local maxMotion=0
local startMotion=nil
local base=assert(io.open(mm and 'C:/nes/Mega Man 2 (USA).nes' or 'C:/nes/Metroid (USA).nes','rb'))
local original=base:read('*a');base:close()
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
if mm then
 emu.addMemoryCallback(function()if r(0x29)==13 then w(0x2a,4)end end,emu.callbackType.exec,N.stage_select_loop)
end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,
  right=t>50 and t%300<120,left=t>50 and t%300>=180,
  a=t>50 and t%90<25,b=t>50 and t%12<2})
 setPad(1,{})
end,emu.eventType.inputPolled)
local function step()
 if mm and r(0x29)~=14 then return end
 if not entered then entered=f end
 updates=updates+1
 -- Refill native health for a long replay; keep real enemy/projectile AI.
 if mm then w(0x6c0,28)
 else w(0x106,0);w(0x107,9)end
 startMotion=emu.getState()['cpu.cycleCount']
end
emu.addMemoryCallback(step,emu.callbackType.exec,mm and H.Motion or H.BeforeHandler)
emu.addMemoryCallback(function()
 if startMotion then maxMotion=math.max(maxMotion,emu.getState()['cpu.cycleCount']-startMotion);startMotion=nil end
end,emu.callbackType.exec,mm and N.update_entity_positions or N.AreaRoutine)
emu.addMemoryCallback(function(a,v)
 if not entered or f-entered<40 then return end
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled'] then
  lateWrites=lateWrites+1
  if lateWrites<4 then print(string.format('LATE f=%d PC=%04X line=%d',f,s['cpu.pc'],s['ppu.scanline']))end
 end
end,emu.callbackType.write,0x2007)
emu.addMemoryCallback(function(a,v)
 if not entered then return end
 local pc=emu.getState()['cpu.pc']
 local bank=pc>=0xc000 and (mm and 15 or 7) or r(mm and 0x29 or 0x23)
 local off=16+bank*16384+pc-3-(pc>=0xc000 and 0xc000 or 0x8000)
 -- Mapper writes must be an actual STA instruction at the same place in
 -- the verified original ROM, not an accidental RMW/dispatch into data.
 local legal=original:byte(off+1)==0x8d and original:byte(off+2)==(a&255) and original:byte(off+3)==(a>>8)
 if not legal then badMapper=badMapper+1;if badMapper<4 then print(string.format('MAPPER PC=%04X addr=%04X value=%02X',pc,a,v))end end
end,emu.callbackType.write,0x8000,0xFFFF)
emu.addEventCallback(function()
 f=f+1
 if not entered then assert(f<2000,'native entry');return end
 local t=f-entered
 if t==700 then local out=assert(io.open(TEST_ROOT..'/build/replay.png','wb'));out:write(emu.takeScreenshot());out:close()end
 if t==1500 then
  assert(updates>800,'normal game updates continue throughout the replay')
  assert(lateWrites==0,'VRAM data writes stay out of visible rendering')
  assert(badMapper==0,'only native mapper transactions write ROM addresses')
  local out=assert(io.open(TEST_ROOT..'/build/replay-timing.json','w'))
  out:write(string.format('{"video_frames":%d,"player_updates":%d,"max_player_path_cycles":%d,"visible_vram_writes":%d,"unexpected_mapper_writes":%d}\n',1500,updates,maxMotion,lateWrites,badMapper));out:close()
  print('PASS '..GAME..' 1500-frame moving/shooting replay; '..updates..' player updates; max player path '..maxMotion..' CPU cycles; clean VRAM/mapper writes')
  emu.stop(0)
 end
end,emu.eventType.endFrame)
