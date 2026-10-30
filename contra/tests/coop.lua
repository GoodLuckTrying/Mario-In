local f=0
local initial={}
local jumping={false,false}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
emu.addEventCallback(function()
 setPad(0,{start=f==120 or f==200 or f==400,select=f==180,
  right=f>=740 and f<780,a=f>=1000 and f<1025})
 setPad(1,{right=f>=740 and f<780,a=f>=1050 and f<1075})
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 f=f+1
 if TRACE and f>=795 and f<890 and f%5==0 then print(string.format('f=%d player=%d,%d privateState=%d,%d vy=%d,%d input=%02X/%02X power=%d/%d',f,r(0x90),r(0x91),r(0x6005),r(0x6085),r(0x6018),r(0x6098),r(0xF1),r(0xF2),r(0x6004),r(0x6084))) end
 if f==735 then initial={r(0x334),r(0x335)} end
 if f>1000 and f<1040 and r(0x6018)>=128 then jumping[1]=true end
 if f>1050 and f<1090 and r(0x6098)>=128 then jumping[2]=true end
 if f==1200 then
  print('mode='..r(0x22)..' P1='..r(0x334)..','..r(0x31A)..' P2='..r(0x335)..','..r(0x31B)..' jumped='..tostring(jumping[1])..','..tostring(jumping[2]))
  assert(r(0x22)==1 and r(0x38)==0 and r(0x39)==0,'Both players must be active')
  assert(r(0x334)>initial[1]+15 and r(0x335)>initial[2]+15,'Both controllers must move independently')
  assert(jumping[1] and jumping[2],'Both characters must jump with their own inputs')
  local o=assert(io.open(TEST_ROOT..'/build/coop.png','wb'));o:write(emu.takeScreenshot());o:close()
  local o=assert(io.open(TEST_ROOT..'/build/coop.wram','wb'));for a=0x6000,0x7FFF do o:write(string.char(r(a))) end;o:close()
  emu.stop(0)
 end
end,emu.eventType.endFrame)
