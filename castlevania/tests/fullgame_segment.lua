-- Controller-only branches from unedited binary savestates. No RAM/register writes.
local loaded=false
local pending=false
local finished=false
local failed=false
local polls=0
local frames=0
local steps=0
local lastStep=0
local state=assert(io.open(FULLGAME.checkpoint,'rb')):read('*a')
local input=assert(io.open(FULLGAME.output..'-input.csv','w'))
input:write('frame,mask\n')
local trace=assert(io.open(FULLGAME.output..'-trace.csv','w'))
trace:write('frame,input,steps,mode,aux,stage,room,x,y,localx,camera,action,health,power,hearts,weapon,multiplier,boss,inv,vy,vx,stomps,firehits,whiphits\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function signed(v) return v>=128 and v-256 or v end
local function world() return r(0x40)+256*r(0x41) end
local function screenshot(tag)
 local file=assert(io.open(FULLGAME.output..tag..'.png','wb'));file:write(emu.takeScreenshot());file:close()
end
local function buttons(text)
 return {a=text:find('A')~=nil,b=text:find('B')~=nil,right=text:find('R')~=nil,left=text:find('L')~=nil,
         up=text:find('U')~=nil,down=text:find('D')~=nil,start=text:find('S')~=nil,select=text:find('T')~=nil}
end
local policy=FULLGAME.policy and dofile(FULLGAME.policy) or function(t)
 local joy=buttons(FULLGAME.inputs)
 -- Repeated B edges keep both the whip and fireball available.
 if joy.b then joy.b=t%20~=19 end
 return joy
end
emu.addEventCallback(function()
 local joy={}
 if loaded and not finished then
  polls=polls+1
  if not pending then joy=policy(polls,r,world) or {} end
  local mask=(joy.a and 128 or 0)+(joy.b and 64 or 0)+(joy.select and 32 or 0)+(joy.start and 16 or 0)+(joy.up and 8 or 0)+(joy.down and 4 or 0)+(joy.left and 2 or 0)+(joy.right and 1 or 0)
  input:write(polls..','..mask..'\n')
 end
 emu.setInput(joy,0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if finished then return end
 if loaded then steps=steps+1;lastStep=frames end
end,emu.callbackType.exec,0xc1e4)
emu.addMemoryCallback(function()
 if finished then return end
 if not loaded then
  loaded=true
  emu.loadSavestate(state)
  return
 end
 if not pending then return end
 finished=true
 local f=assert(io.open(FULLGAME.output..'.state','wb'));f:write(emu.createSavestate());f:close()
 local ram=assert(io.open(FULLGAME.output..'.ram','wb'))
 for a=0,0x7ff do ram:write(string.char(r(a))) end
 for a=0x6000,0x62ff do ram:write(string.char(r(a))) end
 ram:close()
 screenshot('')
 local meta=assert(io.open(FULLGAME.output..'.json','w'))
 meta:write(string.format('{"input_frames":%d,"frames":%d,"logic_steps":%d,"stage":%d,"room":%d,"mode":%d,"aux":%d,"x":%d,"y":%d,"health":%d,"power":%d,"weapon":%d,"multiplier":%d,"failed":%s,"controller_only":true}',polls,frames,steps,r(0x28),r(0x46),r(0x18),r(0x19),world(),r(0x3f),r(0x45),r(0x6001),r(0x15b),r(0x64),tostring(failed)))
 meta:close();input:close();trace:close()
 print('Checkpoint '..FULLGAME.output..' stage '..r(0x28)..' room '..r(0x46)..' x '..world()..' y '..r(0x3f)..' HP '..r(0x45)..' inputs '..polls)
 emu.stop(failed and 1 or 0)
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function()
 if not loaded or finished then return end
 frames=frames+1
 if frames>60 and frames-lastStep>120 then
  screenshot('-stopped');input:flush();trace:flush()
  print('FAIL Native game logic stopped: frame '..frames..' last step '..lastStep..' bank '..r(0x27)..' PC '..emu.getState()['cpu.pc'])
  emu.stop(1);return
 end
 if pending then return end
 trace:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frames,polls,steps,r(0x18),r(0x19),r(0x28),r(0x46),world(),r(0x3f),r(0x38c),r(0x2e)+256*r(0x2f),r(0x46c),r(0x45),r(0x6001),r(0x71),r(0x15b),r(0x64),r(0x1a9),r(0x600d),signed(r(0x6005)),signed(r(0x6071)),r(0x6045),r(0x6046),r(0x603f)))
 if frames%120==0 then
  input:flush();trace:flush()
  print('step '..frames..' stage '..r(0x28)..' room '..r(0x46)..' x '..world()..' y '..r(0x3f)..' action '..r(0x46c)..' HP '..r(0x45))
 end
 if frames<=20 then trace:flush();input:flush() end
 if frames%300==0 then screenshot('-'..frames) end
 if not FULLGAME.allow_death and (r(0x18)==6 or (r(0x45)==0 and r(0x18)==5)) then failed=true;pending=true end
 if polls>=FULLGAME.frames then pending=true end
end,emu.eventType.endFrame)
