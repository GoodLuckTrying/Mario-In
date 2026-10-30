local frame = 0
local root = (TEST_ROOT..'/analysis/')
local log = assert(io.open(root .. 'baseline.csv', 'w'))
log:write('frame,mode,stage,screen,action,x,y,health,held\n')
local function read(a) return emu.read(a, emu.memType.nesDebug) end
emu.addEventCallback(function()
  emu.setInput({start=frame==120 or frame==160, right=frame>430 and frame<700, a=false,b=false,up=false,down=false,left=false,select=false},0)
end, emu.eventType.inputPolled)
emu.addEventCallback(function()
  frame = frame+1
  if frame%10==0 then
    log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d\n',frame,read(0x18),read(0x28),read(0x2f),read(0x46c),read(0x38c),read(0x3f),read(0x45),read(0xf7)))
  end
  if frame==430 or frame==690 or frame==900 or frame==1100 then
    local pixels=emu.getScreenBuffer(); local f=assert(io.open(root .. 'baseline-' .. frame .. '.argb','wb')); for i=1,#pixels do f:write(string.pack('<I4',pixels[i] & 0xffffffff)) end; f:close()
    local f=assert(io.open(root .. 'baseline-' .. frame .. '.state.txt','w')); for k,v in pairs(emu.getState()) do f:write(tostring(k)..'='..tostring(v)..'\n') end; f:close()
    local f=assert(io.open(root .. 'baseline-' .. frame .. '.png','wb')); f:write(emu.takeScreenshot()); f:close()
    local f=assert(io.open(root .. 'baseline-' .. frame .. '.ram','wb')); for a=0,0x7ff do f:write(string.char(read(a))) end; f:close()
    local f=assert(io.open(root .. 'baseline-' .. frame .. '.chr','wb')); for a=0,0x1fff do f:write(string.char(emu.read(a,emu.memType.nesPpuDebug))) end; f:close()
  end
  if frame>=1200 then log:close(); emu.stop(0) end
end, emu.eventType.endFrame)
