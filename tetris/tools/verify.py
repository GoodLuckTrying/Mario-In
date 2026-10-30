"""Bind native CPU, graphics and gameplay replays to the delivered ROM."""
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
import hashlib,json,subprocess,sys,time
from native import ROOT,BASE,SHA
NAME='Mario in Tetris'
def main():
    subprocess.run([sys.executable,str(ROOT/'tools/verify_cpu.py')],check=True)
    subprocess.run([sys.executable,str(ROOT/'tools/verify_vs_cpu.py')],check=True)
    subprocess.run([sys.executable,str(ROOT/'tools/verify_updates_cpu.py')],check=True)
    subprocess.run([sys.executable,str(ROOT/'tools/verify_auto_cpu.py')],check=True)
    subprocess.run([sys.executable,str(ROOT.parent/'tools/audit_all_physics.py'),'--candidate','--game','tetris','--require-match'],check=True,stdout=subprocess.DEVNULL)
    logs=ROOT/'build/verification';logs.mkdir(exist_ok=True)
    rom=ROOT/'dist'/f'{NAME}.nes'
    jobs=[]
    def replay(name,script,defs=None,original=False):jobs.append((name,script,defs or {},original))
    replay('live-SMB1-air-coasting-and-fall-fractions','physics-audit')
    replay('shared-controls-and-hardware-graphics','runtime')
    replay('b-type-shared-controls','runtime',{'TYPE_B':'true'})
    for mode in ['stomp','head','lock','line']:replay(mode,'interaction',{'MODE':repr(mode)})
    for offset in range(8):replay('head-break-alignment-'+str(offset),'head-break',{'OFFSET':offset})
    for mode in ['busy','just-locked']:replay('head-break-'+mode,'head-break',{'MODE':repr(mode)})
    replay('pause','pause');replay('fresh-reset','reset');replay('attract-return','demo');replay('b-ending','ending')
    replay('solo-vs-menu-and-back','menu')
    for case in ['held','together','submenu','a-only','plain']:
        replay('auto-shortcut-'+case,'auto-menu',{'CASE':repr(case)})
    replay('auto-classic-unassisted','auto-runtime')
    for level in [19,29]:replay('auto-classic-gravity-'+str(level),'auto-runtime',{'LEVEL':level,'END_T':5000})
    for mode in ['tetris','topout','pause','reset']:replay('auto-native-'+mode,'auto-fixture',{'MODE':repr(mode)})
    replay('auto-native-ten-lines','auto-fixture',{'SEED_LINES':6})
    replay('auto-native-high-start-threshold','auto-fixture',{'LEVEL':9,'SEED_LINES':6})
    replay('vs-human-controller-roles','vs-runtime',{'HUMAN':'true'})
    replay('vs-cpu-normal-tetrises','vs-runtime',{'END_T':5000})
    for level in [9,19,29]:replay('vs-cpu-frame-budget-level-'+str(level),'vs-runtime',{'LEVEL':level})
    replay('vs-cpu-native-tetris','vs-tetris')
    replay('vs-cpu-ten-line-level-up','vs-tetris',{'SEED_LINES':6})
    replay('vs-escape-permanent-levels','vs-progress')
    replay('vs-falling-head-death','interaction',{'MODE':repr('head'),'VS':'true'})
    for scoring in [True,False]:replay('vs-exit-'+('pending-score'if scoring else'needs-jump'),'vs-exit-edge',{'DURING_SCORE':str(scoring).lower()})
    for human in [True,False]:replay('vs-pause-'+('human'if human else'cpu'),'vs-pause',{'HUMAN':str(human).lower()})
    for mode in ['walk','walk-left','push','push-left','pin','rotate']:replay('live-sides-'+mode,'vs-sides',{'MODE':repr(mode)})
    for mode,defs in [('a',{}),('start',{'USE_START':'true'}),('auto',{'AUTO':'true'})]:replay('round-clear-'+mode,'vs-clear',defs)
    for level in [9,10,19,29,99]:replay('active-hunt-level-'+str(level),'vs-hunt',{'LEVEL':level})
    for mode in ['divert','dodge','corner']:replay('active-hunt-'+mode,'vs-hunt',{'MODE':repr(mode)})
    for height in range(6):replay('b-height-'+str(height),'type-b',{'HEIGHT':height})
    for level in [0,9,19,29]:
        for kind in ['original','hack']:
            file=(ROOT/'build'/f'piece-{level}-{kind}.txt').as_posix()
            replay(f'piece-{level}-{kind}','piece-reference',{'LEVEL':level,'HACK':str(kind=='hack').lower(),'TRACE_FILE':repr(file)},kind=='original')
    def run(job):
        name,script,defs,original=job;start=time.time()
        args=[sys.executable,str(ROOT.parent/'tools/port_probe.py'),'tetris',str(ROOT/'tests'/f'{script}.lua'),'--rom',str(BASE if original else rom),'--timeout','45']
        for k,v in defs.items():args+=['--define',f'{k}={v}']
        r=subprocess.run(args,cwd=ROOT.parent,capture_output=True,text=True,timeout=55)
        (logs/(name+'.log')).write_text(r.stdout+r.stderr)
        return {'name':name,'passed':r.returncode==0 and 'PASS ' in r.stdout and 'FAIL ' not in r.stdout,'seconds':round(time.time()-start,2)}
    results=[]
    with ThreadPoolExecutor(max_workers=4)as pool:
        for future in as_completed([pool.submit(run,j)for j in jobs]):
            item=future.result();results.append(item);print(item['name'],'PASS'if item['passed']else'FAIL',flush=True)
    assert all(c['passed']for c in results),'See build/verification for failing replays'
    for level in [0,9,19,29]:
        a=(ROOT/'build'/f'piece-{level}-original.txt').read_bytes();b=(ROOT/'build'/f'piece-{level}-hack.txt').read_bytes()
        assert a==b,f'Native Tetris must remain exact at level {level}'
        results.append({'name':f'native-piece-and-board-equivalence-{level}','passed':True,'frames':180})
    data=rom.read_bytes();meta=json.loads((ROOT/'build/manifest.json').read_text());old=BASE.read_bytes()
    sha=hashlib.sha256(data).hexdigest()
    assert sha==meta['output_sha256']
    assert hashlib.sha256(old).hexdigest()==SHA
    assert (ROOT/'build/native.nes').read_bytes()[16:]==old[16:]
    assert hashlib.sha256(Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()).hexdigest()==meta['smb_sha256']
    changed={a for h in meta['hooks']for a in range(h['address'],h['address']+h['length'])}
    for a in range(0x8000,0x10000):
        if a not in changed:assert data[16+a-0x8000]==old[16+a-0x8000],hex(a)
    assert data[16:18]==old[16:18], 'Preserve INC initRam as the native MMC1 reset port'
    source=(ROOT/'build/hack.bin').read_bytes();assert data[0x8010+30*4096:]==source
    assert all(b==0xff for b in source[0x1800:]),'Work RAM code must end below player state'
    patch=(ROOT/'dist'/f'{NAME}.ips').read_bytes();assert patch[:5]==b'PATCH';p=5;out=bytearray(old)
    while patch[p:p+3]!=b'EOF':
        a=int.from_bytes(patch[p:p+3],'big');n=int.from_bytes(patch[p+3:p+5],'big');p+=5;assert n
        if a+n>len(out):out.extend(bytes(a+n-len(out)))
        out[a:a+n]=patch[p:p+n];p+=n
    assert out==data
    cpu=json.loads((ROOT/'build/cpu-verification.json').read_text());assert cpu['rom_sha256']==sha
    results+=cpu['checks']
    cpu=json.loads((ROOT/'build/vs-cpu-verification.json').read_text());assert cpu['rom_sha256']==sha
    results+=cpu['checks']
    cpu=json.loads((ROOT/'build/updates-cpu-verification.json').read_text());assert cpu['rom_sha256']==sha
    results+=cpu['checks']
    cpu=json.loads((ROOT/'build/auto-cpu-verification.json').read_text());assert cpu['rom_sha256']==sha
    results+=cpu['checks']
    results.append({'name':'expanded SMB1 source movement comparison','passed':True})
    results.append({'name':'original hashes, exact native reference, documented PRG changes, code bounds and IPS reconstruction','passed':True})
    report={'rom_sha256':sha,'passed':True,'checks':sorted(results,key=lambda x:x['name']),
        'originals_unchanged':True,'ips_reconstructs_rom':True,'controls':'Solo shared / VS P1 Mario, P2 or CPU pieces / Select+Start Auto-Classic',
        'limits':['Emulator replays and deterministic seeded interaction fixtures are not an unassisted full game or a physical hardware test.']}
    (ROOT/'dist/verification.json').write_text(json.dumps(report,indent=2))
    print('All',len(results),'checks passed; originals unchanged; IPS verified.',flush=True)
if __name__=='__main__':main()
