dofile(TEST_ROOT..'/tests/common.lua')
local menu,sub=nil,nil
CASE=CASE or 'held'
emu.addMemoryCallback(function()menu=menu or f end,emu.callbackType.exec,H.MenuGate)
emu.addEventCallback(function()
 if done then return end
 local pad={}
 if menu and r(N.gameMode)==2 and r(0x78a1)<2 then
  local t=f-menu
  if r(0x78a1)==1 then
   sub=sub or f
   pad.select=CASE=='submenu' and f-sub>=20 and f-sub<=30
   pad.start=f-sub==30
  elseif CASE=='submenu' then
   pad.down=t==20;pad.a=t==25
  elseif CASE=='a-only' then
   pad.select=t>=20 and t<=30;pad.a=t==30
  elseif CASE=='plain' then pad.start=t==30
  else
   pad.select=t>=(CASE=='together' and 30 or 20) and t<=31
   pad.start=t==30
  end
 elseif not first then pad.start=f%90<4 end
 setPad(0,pad);setPad(1,{})
end,emu.eventType.inputPolled)
local function ppu(a)return emu.read(a,emu.memType.nesPpuDebug)end
function tick(t)
 if t==40 then
  local mode=(CASE=='held' or CASE=='together')and 3 or CASE=='plain' and 0 or CASE=='submenu' and 2 or 1
  assert(r(0x78a0)==mode,'shortcut requires held Select and fresh Start on the main page only: '..CASE)
  assert(r(N.numberOfPlayers)==1 and r(N.gameType)==0,'Auto uses one native A-Type board')
  if mode~=0 then
   local label=mode==3 and {10,30,29,24,255,255,255} or mode==1 and {31,28,255,12,25,30,255} or {31,28,255,25,2,255,255}
   for i=1,7 do assert(ppu(0x2081+i)==label[i],'HUD replaces all seven A-TYPE tiles without a leftover E')end
  end
  if mode==3 then assert(r(0x7800)~=0x4d,'Auto does not spawn Mario')end
  screenshot('auto-menu-'..CASE)
  finish('Auto-Classic shortcut '..CASE..' and complete gameplay label')
 end
end
