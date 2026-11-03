"""Search native controller timing from an opaque checkpoint; no memory writes."""
from pathlib import Path
import json
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'analysis/fullgame/death-second-hop-search'
choices=[dict(jump=j,hold=h,target=x) for j in range(45,86,5) for h in [2,6,12,20] for x in [108,124,140,160]]
def lua(v):
    if isinstance(v,dict):return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    return json.dumps(v)
script=r'''local choices=CHOICES
local idx=0
local pending=true
local loaded=false
local t=0
local step=0
local total=0
local root=assert(io.open(ROOTSTATE,'rb')):read('*a')
local csv=assert(io.open(OUT..'.csv','w'))
csv:write('trial,jump,hold,target,frames,health,boss,x,y\n')
local r=function(a)return emu.read(a,emu.memType.nesDebug) end
local policy=nil
local best=64
emu.addMemoryCallback(function()
 if not pending then return end
 pending=false;idx=idx+1
 if idx>#choices then csv:close();print('SEARCH complete without clear');emu.stop(0);return end
 DEATH_SEARCH_PARAMS=choices[idx]
 policy=dofile(POLICY)
 t=0;step=0
 emu.loadSavestate(root);loaded=true
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function()
 local joy={}
 if loaded and not pending then
  t=t+1;total=total+1
  joy=policy(t,r,function()return r(0x40)+r(0x41)*256 end) or {}
 end
 emu.setInput(joy,0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 if not loaded or pending then return end
 step=step+1
 if r(0x1a9)==0 or r(0x45)==0 or r(0x18)==6 or t>=500 then
  local p=choices[idx]
  csv:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d\n',idx,p.jump,p.hold,p.target,t,r(0x45),r(0x1a9),r(0x38c),r(0x3f)))
  csv:flush()
  if r(0x1a9)<best then best=r(0x1a9);print('BEST trial '..idx..' boss '..best..' HP '..r(0x45)..' '..p.jump..' '..p.hold..' '..p.target) end
  if r(0x1a9)==0 and r(0x45)>0 then
   print('WIN trial '..idx..' '..p.jump..' '..p.hold..' '..p.target..' polls '..total)
   csv:close();emu.stop(0);return
  end
  pending=true
 end
end,emu.eventType.endFrame)
'''
script=script.replace('CHOICES',lua(choices)).replace('ROOTSTATE',lua((ROOT/'analysis/fullgame/stage15-death-center-pre-hit.state').as_posix())).replace('POLICY',lua((ROOT/'analysis/fullgame/death-second-hop-controller.lua').as_posix())).replace('OUT',lua(out.as_posix()))
out.with_suffix('.lua').write_text(script)
p=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout','--timeout=180','--doNotSaveSettings',str(out.with_suffix('.lua')),'C:/nes/Mario In/Mario in Castlevania.nes'],capture_output=True,text=True,timeout=195)
out.with_suffix('.log').write_text(p.stdout+p.stderr)
print('\n'.join(line for line in p.stdout.splitlines() if line.startswith(('BEST','WIN','SEARCH','Error','Lua'))))
sys.exit(p.returncode)
