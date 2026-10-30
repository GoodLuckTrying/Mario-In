"""Native controller-only search from the first-form clear checkpoint."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
ROM=ROOT/'build/Mario in Castlevania.nes'
out=ROOT/'analysis/fullgame/dracula-second-search'
choices=[dict(distance=d,hold=h,release=3,water=z,airDuck=1) for z in [1,0] for h in [16,20,24,12,30,40] for d in [40,44,48,36,52,56]]
def lua(v):
 if isinstance(v,dict):return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 return json.dumps(v)
script=r'''local choices=CHOICES
local idx=0;local pending=true;local loaded=false;local t=0;local best=64
local root=assert(io.open(ROOTSTATE,'rb')):read('*a')
local csv=assert(io.open(OUT..'.csv','w'));csv:write('trial,distance,hold,water,frames,health,boss,phase,x,y\n')
local r=function(a)return emu.read(a,emu.memType.nesDebug)end
local policy=nil
emu.addMemoryCallback(function()
 if not pending then return end
 pending=false;idx=idx+1
 if idx>#choices then csv:close();print('SEARCH complete without clear');emu.stop(0);return end
 DRACULA_SECOND_PARAMS=choices[idx];policy=dofile(POLICY);t=0
 emu.loadSavestate(root);loaded=true
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function()
 local joy={}
 if loaded and not pending then t=t+1;joy=policy(t,r,function()return r(0x40)+r(0x41)*256 end) or {} end
 emu.setInput(joy,0)
end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 if not loaded or pending then return end
 local win=r(0x434+7)==49 and r(0x584+7)==6
 if win or r(0x45)==0 or r(0x18)==6 or t>=5000 then
  local p=choices[idx]
  csv:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n',idx,p.distance,p.hold,p.water,t,r(0x45),r(0x1a9),r(0x7a),r(0x38c),r(0x3f)));csv:flush()
  if r(0x7a)==1 and r(0x1a9)<best then best=r(0x1a9);print('BEST '..idx..' boss '..best..' HP '..r(0x45)..' distance '..p.distance..' hold '..p.hold..' water '..p.water) end
  if win and r(0x45)>0 then print('WIN '..idx..' distance '..p.distance..' hold '..p.hold..' water '..p.water..' frames '..t);csv:close();emu.stop(0);return end
  pending=true
 end
end,emu.eventType.endFrame)
'''
for key,val in {'CHOICES':choices,'ROOTSTATE':(ROOT/'analysis/fullgame/stage18-dracula-first-form.state').as_posix(),'POLICY':(ROOT/'analysis/fullgame/dracula-second-form-controller.lua').as_posix(),'OUT':out.as_posix()}.items():script=script.replace(key,lua(val))
out.with_suffix('.lua').write_text(script)
sha=hashlib.sha256(ROM.read_bytes()).hexdigest()
p=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout','--timeout=180','--doNotSaveSettings',str(out.with_suffix('.lua')),str(ROM)],capture_output=True,text=True,timeout=195)
out.with_suffix('.log').write_text(p.stdout+p.stderr)
assert hashlib.sha256(ROM.read_bytes()).hexdigest()==sha
print('\n'.join(line for line in p.stdout.splitlines() if line.startswith(('BEST','WIN','SEARCH','FAIL','Error','Lua'))))
raise SystemExit(p.returncode)
