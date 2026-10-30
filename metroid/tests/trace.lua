local f=0
local entered=nil
local hist={}
local idx=1
local bad=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
emu.addEventCallback(function()
 local t=entered and f-entered or -1
 setPad(0,{start=not entered and f%120<3,a=t>60 and t%80<25});setPad(1,{})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not entered then entered=f end
end,emu.callbackType.exec,H.BeforeHandler)
emu.addMemoryCallback(function(address)
 if not entered then return end
 hist[idx]=string.format('%04X',address);idx=idx%64+1
 if address==0xFFB0 or address==0xC01A or address==0xBFB0 then
  print('RESET at '..f..' hp='..r(0x106)..','..r(0x107)..' bank='..r(0x23)..' mmc='..r(0x25)..' upper='..r(0x28));local o=assert(io.open(TEST_ROOT..'/build/reset-state.json','w'));for k,v in pairs(emu.getState())do o:write(tostring(k)..'='..tostring(v)..'\n')end;o:close()
  for i=0,63 do print(hist[(idx+i-1)%64+1])end
  emu.stop(0)
 end
end,emu.callbackType.exec,0x6000,0xFFFF)
emu.addMemoryCallback(function(address,value)
 local s=emu.getState()
 if entered and s['ppu.scanline']>=0 and s['ppu.scanline']<240 and s['ppu.mask.backgroundEnabled'] then
  bad=bad+1
  if bad<10 then print(string.format('BAD PPU %04X %02X PC=%04X f=%d line=%d',address,value,s['cpu.pc'],f,s['ppu.scanline']))end
 end
end,emu.callbackType.write,0x2007)
emu.addEventCallback(function()
 f=f+1
 if f==1600 then print('END bad writes '..bad);emu.stop(0)end
end,emu.eventType.endFrame)
