local f=0
local motion=0
local entered=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addEventCallback(function()
 setPad(0,{start=entered==0 and f%120<3,a=(entered==0 and f%120<3) or (entered>0 and (f-entered)%100<25),right=(entered==0 and f%120>=10 and f%120<13) or (entered>0 and (f-entered)%300<110),b=entered>0 and (f-entered)%20<2});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 motion=motion+1
 if entered==0 then entered=f;print('ENTER '..f);local file=assert(io.open(TEST_ROOT..'/build/code.bin','rb'));local code=file:read('*a');file:close();for i=1,#code do assert(r(0x6000+i-1)==code:byte(i),'code RAM byte '..i)end end
end,emu.callbackType.exec,H.Motion)
for _,key in ipairs({'show_title_screen','show_stage_select','game_init_respawn'})do
 emu.addMemoryCallback(function()print(key..' f='..f)end,emu.callbackType.exec,N[key])
end
emu.addEventCallback(function()
 f=f+1
 if f%120==0 then print('F '..f..' bank '..r(0x29)..' sub '..r(0x2c)..' xy '..r(0x460)..','..r(0x4a0)..' state '..r(H.M_STATE)..' magic '..r(H.M_MAGIC)..' motion '..motion)end
 if f==1700 or f==1800 or f==1900 then
  local out=assert(io.open(TEST_ROOT..'/build/probe-'..f..'.png','wb'));out:write(emu.takeScreenshot());out:close()
 end
 if f==2200 then assert(motion>100,'must enter stage');print('PASS boot probe '..motion);emu.stop(0)end
end,emu.eventType.endFrame)
