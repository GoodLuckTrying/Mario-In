"""Directed old-checkpoint workload benchmark; never claims a fresh clear."""
import argparse, csv, hashlib, json, statistics, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CASES=['stage10-platform-braked','stage10-second-raft-landing','stage10-fourth-raft-landed',
       'stage12-healthy-bridge','stage12-frankenstein-48hp',
       'stage14-native-respawn','stage14-upper-left-hall','stage14-west-corridor']
def main():
    p=argparse.ArgumentParser();p.add_argument('rom',type=Path);p.add_argument('tag');a=p.parse_args()
    out=ROOT/'analysis/physics-fix-2026-10-23';out.mkdir(exist_ok=True,parents=True)
    stem=out/a.tag
    source=r'''
local cases=CASES
local n,t,loaded=0,0,false
local pending=false
local row=nil;local startSprite=nil;local startPlayer=nil
local f=assert(io.open(OUTPUT..'.csv','w'))
f:write('case,tick,stage,action,health,aux,pause,stun,cycles,player,sprites,missed\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function cycle() return emu.getState()['cpu.cycleCount'] end
local function load()
 n=n+1;t=0;row=nil
 if n>#cases then f:close();print('Completed directed workload cases '..#cases);emu.stop(0);return end
 local h=assert(io.open(cases[n],'rb'));local s=h:read('*a');h:close()
 emu.loadSavestate(s);loaded=true
end
emu.addEventCallback(function()
 emu.setInput({b=loaded and t%20~=19,down=loaded and t%120<60,a=loaded and t%120>=80 and t%120<100},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if not loaded then return end
 if r(0x1b)==0 then row={start=cycle(),stage=r(0x28),action=r(0x46c),health=r(0x45),aux=r(0x19),pause=r(0x1f),stun=r(0x47),sprites=0,player=0,missed=0}
 elseif row then row.missed=row.missed+1 end
end,emu.callbackType.exec,0xc052)
emu.addMemoryCallback(function() if row then startSprite=cycle() end end,emu.callbackType.exec,0xc0ac)
emu.addMemoryCallback(function() if row and startSprite then row.sprites=cycle()-startSprite end end,emu.callbackType.exec,0xc0af)
emu.addMemoryCallback(function() if row then startPlayer=cycle() end end,emu.callbackType.exec,0x934c)
emu.addMemoryCallback(function() if row and startPlayer then row.player=cycle()-startPlayer end end,emu.callbackType.exec,0xcf02)
emu.addMemoryCallback(function()
 if not loaded then load();return end
 if pending then pending=false;load();return end
 if row and r(0x18)==5 then
  f:write(table.concat({n,t,row.stage,row.action,row.health,row.aux,row.pause,row.stun,cycle()-row.start,row.player,row.sprites,row.missed},',')..'\n');f:flush()
 end
 row=nil
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function() if loaded and not pending then t=t+1;if t>=480 then pending=true end end end,emu.eventType.endFrame)
'''.replace('CASES','{'+','.join(json.dumps((ROOT/'analysis/fullgame'/f'{c}.state').as_posix()) for c in CASES)+'}').replace('OUTPUT',json.dumps(stem.as_posix()))
    script=stem.with_suffix('.lua');script.write_text(source)
    rom=a.rom.resolve();sha=hashlib.sha256(rom.read_bytes()).hexdigest()
    r=subprocess.run([sys.executable,str(ROOT/'tools/run_mesen.py'),str(script),str(rom),'--timeout=90'],text=True,capture_output=True,timeout=110)
    stem.with_suffix('.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stdout+r.stderr
    rows=[{k:int(v) for k,v in r.items()} for r in csv.DictReader(stem.with_suffix('.csv').open())]
    report={'candidate_sha256':sha,'cases':CASES,'case_state_sha256':{c:hashlib.sha256((ROOT/f'analysis/fullgame/{c}.state').read_bytes()).hexdigest() for c in CASES},'evidence':'Directed workloads loaded from previous-release opaque checkpoints; no full-game clear claim','stages':{}}
    for stage in sorted({r['stage'] for r in rows}):
        group=[r for r in rows if r['stage']==stage and r['health']>0 and r['action'] in (0,1) and r['aux']==6 and r['pause']==0 and r['stun']==0]
        if not group:continue
        d={'updates':len(group),'missed':sum(r['missed'] for r in group)}
        d['missed_percent']=round(d['missed']*100/(len(group)+d['missed']),3)
        for k in ('cycles','player','sprites'):
            x=sorted(r[k] for r in group);d[k]={'mean':round(statistics.mean(x)),'p95':x[int(.95*(len(x)-1))],'max':max(x)}
        report['stages'][stage]=d
    assert hashlib.sha256(rom.read_bytes()).hexdigest()==sha
    stem.with_suffix('.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
