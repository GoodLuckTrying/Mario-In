"""Original-ROM fireball/stomp comparisons plus directed render/hurtbox fixtures."""
import csv, hashlib, json, re, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'analysis/physics-fix-2026-10-23/integration'
def symbol(name):
    listing=(ROOT/'build/mario.lst').read_text()
    matches=re.findall(r'^([0-9A-F]{6})r\s+\d+\s+'+re.escape(name)+r':',listing,re.M)
    if not matches:
        matches=re.findall(r'^([0-9A-F]{6})r\s+\d+\s+(?:[0-9A-F]{2} )+\s*(?:smallSprite|bigSprite) '+re.escape(name)+r',',listing,re.M)
    assert len(matches)==1,(name,matches)
    return int(matches[0],16)
def run(script,rom):
    r=subprocess.run([sys.executable,str(ROOT/'tools/run_mesen.py'),str(script),str(rom),'--timeout=30'],capture_output=True,text=True,timeout=45)
    script.with_suffix('.log').write_text(r.stdout+r.stderr)
    assert r.returncode==0,r.stdout+r.stderr
def main():
    rom=Path(sys.argv[1]).resolve();OUT.mkdir(parents=True,exist_ok=True)
    for kind in ('fireball','stomp'):
        for tag in ('smb','hybrid'):
            s=(ROOT/f'analysis/physics-audit-2026-10-23/{kind}-{tag}.lua').read_text()
            s=re.sub(r'AUDIT_OUTPUT=.*', 'AUDIT_OUTPUT='+json.dumps((OUT/f'{kind}-{tag}.csv').as_posix()),s)
            if kind=='stomp' and tag=='hybrid':
                s=re.sub(r'AUDIT_STOMP_ENTRY=\d+',f'AUDIT_STOMP_ENTRY={0x9e50+symbol("StompEnemy")}',s)
                s=re.sub(r'AUDIT_STOMP_END=\d+',f'AUDIT_STOMP_END={0x9e50+symbol("EnemyBounds")-1}',s)
            script=OUT/f'{kind}-{tag}.lua';script.write_text(s)
            run(script,Path('C:/nes/Super Mario Bros. (World).nes') if tag=='smb' else rom)
    read=lambda n:list(csv.DictReader((OUT/n).open()))
    stomp=[read(f'stomp-{tag}.csv') for tag in ('smb','hybrid')]
    assert stomp[0]==stomp[1],stomp
    fire=[read(f'fireball-{tag}.csv') for tag in ('smb','hybrid')]
    launches=[]
    for c in range(4):
        traces=[[r for r in rows if int(r['case'])==c and int(r['active'])>0] for rows in fire]
        if c>=2:assert not any(traces),'Crouching must prevent shooting'
        else:
            assert all(traces),'Standing must allow shooting'
            x,y=traces[0][0],traces[1][0]
            assert (x['visible_x'],x['visible_y'])==(y['visible_x'],y['visible_y']),(x,y)
            launches.append({'direction':'right' if c==0 else 'left','x':int(x['visible_x']),'y':int(x['visible_y'])})
    # Tables resolved from this build, then selected through the real renderer.
    sprite_names=['SmallWalk1','SmallWalk2','SmallWalk3','BigWalk1','BigWalk2','BigWalk3','SmallJump','BigJump']
    cfg={'pointers':[0xbb10+symbol(n) for n in sprite_names],
         'body':0x9e50+symbol('UpdateBodySize')}
    script=OUT/'bounds-animation.lua'
    script.write_text('AUDIT_POINTERS={'+','.join(map(str,cfg['pointers']))+'}\nAUDIT_BODY='+str(cfg['body'])+'\n'
                      +'dofile('+json.dumps((ROOT/'tests/physics-bounds-animation.lua').as_posix())+')\n')
    run(script,rom)
    result={'candidate_sha256':hashlib.sha256(rom.read_bytes()).hexdigest(),'passed':True,
            'stomp':stomp[1],'fireball_launches':launches,'crouched_launches':0,
            'bounds_animation_cases':24,'evidence':'Directed RAM fixtures execute actual original-ROM handlers and candidate renderer; not a full-game clear'}
    (OUT/'results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if __name__=='__main__':main()
