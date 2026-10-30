local f=0
local menu=false
local began=false
local playerOne=nil
local playerTwo=nil
local kill=false
local p2x=nil
local p2moving=0
local p2shots=0
local boots=0
local function r(a)return emu.read(a,emu.memType.nesDebug)end
local function w(a,v)emu.write(a,v&255,emu.memType.nesDebug)end
emu.addMemoryCallback(function()menu=true end,emu.callbackType.exec,0xc4a5)
emu.addMemoryCallback(function()boots=boots+1;assert(boots==1,'alternating players do not reset the ROM')end,emu.callbackType.exec,H.Boot)
emu.addEventCallback(function()
 local selected=menu and r(0xa3)==1
 setPad(0,{select=menu and not began and not selected,start=menu and not began and selected and f%30<9})
 local t=playerTwo and f-playerTwo or -1
 setPad(1,{right=t>=20 and t<100,a=t>=35 and t<60,b=t>=20 and t%22<6})
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 began=true
 for x=1,16 do w(0x4f0+x,0)end
 if r(0xba)==0 then
  playerOne=playerOne or f
  assert(r(0xa2)==1,'Select starts native two-player mode')
  if f-playerOne>120 and not kill then
   w(0x4f0,(r(0x4f0)&0x9e)|0x21);w(0x647,0);kill=true
  end
 else
  playerTwo=playerTwo or f;p2x=p2x or r(0x5af)
  if r(H.M_SMB_X_SPEED)~=0 then p2moving=p2moving+1 end
  if r(H.FB)>0 then p2shots=p2shots+1 end
 end
end,emu.callbackType.exec,H.Step)
emu.addEventCallback(function()
 f=f+1
 if playerTwo and f-playerTwo==160 then
  assert(p2moving>10 and p2shots>5,'controller two supplies Mario movement and shots')
  assert(r(H.M_FORM)==0 and r(0x4f0)&0x20==0,'player two starts with fresh Fire Mario armor')
  print('PASS actual Select/Start two-player mode, native P1 death/turn change, P2 controls and independent fresh life');emu.stop(0)
 end
 assert(f<4000,'two-player fixture completes')
end,emu.eventType.endFrame)
