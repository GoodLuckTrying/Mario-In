local f=0
local title=0
local entered=nil
local weapon=nil
local savedTitle=false
local weaponDraws=0
local nativeShots=0
local fireShots=0
local firstMenu=nil
local password=nil
local restored=nil
local finished=false
local late=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
local function save(name)local o=assert(io.open(TEST_ROOT..'/build/'..name..'.png','wb'));o:write(emu.takeScreenshot());o:close()end
local function chr(file,base)
 local o=assert(io.open(TEST_ROOT..'/build/'..file,'rb'));local b=o:read('*a');o:close()
 for i=1,#b do assert(emu.read(base+i-1,emu.memType.nesPpuDebug)==b:byte(i),'scene-owned Mario CHR '..file..' byte '..i)end
end
emu.addMemoryCallback(function()if r(0x29)==13 then w(0x2A,4);if restored then finished=true end end end,emu.callbackType.exec,N.stage_select_loop)
emu.addMemoryCallback(function()
 if r(0x29)==13 then title=title+1 end
end,emu.callbackType.exec,H.TitleDraw)
emu.addMemoryCallback(function()
 if r(0x29)==14 and not entered then entered=f end
end,emu.callbackType.exec,H.Motion)
emu.addMemoryCallback(function()
 if r(0x29)==13 then weapon=weapon or f end
end,emu.callbackType.exec,N.weapon_get_screen_init)
emu.addMemoryCallback(function()
 if weapon and r(0x29)==13 then weaponDraws=weaponDraws+1 end
end,emu.callbackType.exec,N.ending_player_render)
emu.addMemoryCallback(function()
 if not entered then return end
 local x=emu.getState()['cpu.x']
 if x==6 or x==7 then fireShots=fireShots+1 else nativeShots=nativeShots+1 end
end,emu.callbackType.exec,N.weapon_spawn_projectile)
emu.addMemoryCallback(function()
 local s=emu.getState()
 if s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled'] then late=late+1 end
end,emu.callbackType.write,0x2007)
-- Enter native post-victory flow after normal movement and simultaneous shots.
emu.addMemoryCallback(function()
 if weapon and r(0x29)==13 then firstMenu=firstMenu or f;if restored then w(N.general_counter,1)end end
end,emu.callbackType.exec,N.weapon_get_menu_loop)
emu.addMemoryCallback(function()if weapon then password=password or f end end,emu.callbackType.exec,N.password_show_grid)
emu.addMemoryCallback(function()if weapon then restored=restored or f end end,emu.callbackType.exec,N.weapon_get_pw_restore_done)
local defeated=false
emu.addMemoryCallback(function()
 if entered and f-entered>150 and not defeated then
  defeated=true;w(N.boss_phase,0xFE);w(N.boss_id,2);w(N.boss_hit_count,1);w(N.boss_hp,0)
 end
end,emu.callbackType.exec,N.process_sound_and_bosses)
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=(not entered and f%120<3)or(firstMenu and f==firstMenu+10)or(password and f==password+30)or(restored and f==restored+20),a=password and not restored and (f-password)%120<2,b=not weapon and t>15 and t%16<2})
 setPad(1,{})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if title>3 and not savedTitle then chr('menu-title.chr',0);save('repaired-title');savedTitle=true end
 if weapon and f-weapon==110 then
  chr('menu-big.chr',0x800);save('repaired-weapon-get')
  assert(weaponDraws>0,'native weapon acquisition renderer')
 end
 if firstMenu and f-firstMenu==1 then chr('menu-big.chr',0x800);save('repaired-weapon-menu')end
 if restored and f-restored==1 then chr('menu-big.chr',0x800);save('repaired-password-return')end
 if finished then
  assert(password and restored,'weapon password display/return retains Mario CHR')
  assert(late==0,'title, weapon and password CHR uploads occur while blanked')
  assert(nativeShots>=3 and fireShots>=3,'B independently fires native shots and Mario fireballs')
  assert(savedTitle,'rooftop intro/title checked')
  print('PASS Mario rooftop/title, weapon-get portrait, password and stage-select return; native and Mario shots '..nativeShots..'/'..fireShots)
  emu.stop(0)
 end
 if f==4499 then save('scene-timeout');print('TRACE title '..title..' entered '..tostring(entered)..' weapon '..tostring(weapon)..' defeated '..tostring(defeated)..' firstMenu '..tostring(firstMenu)..' password '..tostring(password)..' restored '..tostring(restored)..' bank '..r(0x29)..' phase '..r(N.boss_phase))end
 assert(f<4500,'title, native post-victory and weapon-get scene complete')
end,emu.eventType.endFrame)
