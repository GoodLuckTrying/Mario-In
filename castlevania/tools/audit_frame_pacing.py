"""Read-only NMI overrun measurements during the verified full-game replay."""
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'analysis/physics-audit-2026-10-23'
rom=Path('C:/nes/Mario in Castlevania.nes')
manifest=json.loads((ROOT/'analysis/fullgame/stage18-credits-route.json').read_text())
sha=hashlib.sha256(rom.read_bytes()).hexdigest()
assert sha==manifest['rom_sha256']
source=(ROOT/'analysis/fullgame/stage18-credits-fresh.lua').read_text()
source=re.sub(r'^OUTPUT=.*$', 'OUTPUT='+json.dumps((OUT/'pacing-replay').as_posix()),
              source,count=1,flags=re.MULTILINE)
prefix=r'''
local pacing={}
local function pr(a) return emu.read(a,emu.memType.nesDebug) end
local function stat()
 if pr(0x18)~=5 then return nil end
 local stage=pr(0x28)
 if not pacing[stage] then pacing[stage]={vblanks=0,missed=0,updates=0,normal=0,normalMissed=0} end
 return pacing[stage]
end
local function normal()
 return pr(0x19)==6 and pr(0x46c)<2 and pr(0x47)==0 and pr(0x45)>0 and pr(0x22)==0
end
emu.addMemoryCallback(function()
 local s=stat();if not s then return end
 s.vblanks=s.vblanks+1
 if normal() then s.normal=s.normal+1 end
end,emu.callbackType.exec,0xc052)
emu.addMemoryCallback(function()
 local s=stat();if not s then return end
 s.missed=s.missed+1
 if normal() then s.normalMissed=s.normalMissed+1 end
end,emu.callbackType.exec,0xc0c0)
emu.addMemoryCallback(function()
 local s=stat();if s then s.updates=s.updates+1 end
end,emu.callbackType.exec,0xc0b5)
local stop=emu.stop
emu.stop=function(code)
 local f=assert(io.open(PACING_CSV,'w'))
 f:write('stage,vblanks,missed_vblanks,updates,normal_vblanks,normal_missed_vblanks\n')
 for stage=0,31 do
  local s=pacing[stage]
  if s then f:write(string.format('%d,%d,%d,%d,%d,%d\n',stage,s.vblanks,s.missed,s.updates,s.normal,s.normalMissed)) end
 end
 f:close();stop(code)
end
'''.replace('PACING_CSV',json.dumps((OUT/'frame-pacing.csv').as_posix()))
script=OUT/'pacing-replay.lua'
script.write_text(prefix+source)
assert 'emu.write' not in prefix+source and 'loadSavestate' not in prefix+source
result=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout','--timeout=240',
                       '--doNotSaveSettings',str(script),str(rom)],capture_output=True,text=True,timeout=255)
(OUT/'pacing-replay.log').write_text(result.stdout+result.stderr)
assert result.returncode==0,result.stdout[-1000:]+result.stderr[-1000:]
assert result.stdout.count('PASS ')==len(manifest['segments'])
assert 'Fresh-power-on route verified: 56431 controller polls' in result.stdout
assert hashlib.sha256(rom.read_bytes()).hexdigest()==sha
with (OUT/'frame-pacing.csv').open() as f:
    stages=[{k:int(v) for k,v in row.items()} for row in csv.DictReader(f)]
for s in stages:
    s['normal_missed_percent']=round(100*s['normal_missed_vblanks']/max(1,s['normal_vblanks']),3)
    s['normal_effective_fps']=round(60.098811*(1-s['normal_missed_percent']/100),3)
report=dict(candidate_sha256=sha,verified_controller_polls=56431,checkpoints=140,
            full_game_clear=True,fresh_boot_verified=True,stages=stages,
            evidence='Read-only native NMI busy-path counts during the unchanged fixed controller replay')
(OUT/'frame-pacing.json').write_text(json.dumps(report,indent=2))
for s in stages: print(s)
