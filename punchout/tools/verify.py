"""Run the exact candidate through instruction and native Mesen integration tests."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,datetime,importlib.util,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'punchout';sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import sha,install,INSTALL_DIR
def main():
    p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');a=p.parse_args()
    m=json.loads((P/'build/manifest.json').read_text());name=m['name'];rom=P/'dist'/f'{name}.nes';digest=sha(rom.read_bytes());assert digest==m['output_sha256']
    preserved={q:sha(q.read_bytes())for q in INSTALL_DIR.glob('*.nes')if q.stem!=name}
    jobs=[('instructions',[sys.executable,str(P/'tests/instructions.py')])]
    def probe(test,defs=()):
        cmd=[sys.executable,str(ROOT/'tools/port_probe.py'),'punchout',str(P/f'tests/{test}.lua'),'--rom',str(rom),'--timeout','55']
        for d in defs:cmd+=['--define',d]
        return cmd
    for test in ('gameplay','fire_visuals','progression','referee','hurt','demo'):jobs.append((test,probe(test)))
    for fight in range(14):jobs.append((f'roster-{fight}',probe('roster',[f'FIGHT={fight}'])))
    checks=[]
    with ThreadPoolExecutor(max_workers=2)as pool:
        fs={pool.submit(run,key,cmd):key for key,cmd in jobs}
        for f in as_completed(fs):
            key=fs[f];log=f.result();checks.append(dict(name=key,passed=True,log=str(log.relative_to(ROOT)),log_sha256=sha(log.read_bytes())));print('PASS',key,flush=True)
    ins=json.loads((P/'build/instructions.json').read_text());assert ins['rom_sha256']==digest
    checks+=ins['checks'];ref=json.loads((P/'build/reference/source-verification.json').read_text());assert ref['matching_prg']and ref['matching_chr']
    checks.append(dict(name='Exact pinned Tyson Rev 1 disassembly PRG/CHR reconstruction',passed=True))
    for q,d in preserved.items():assert sha(q.read_bytes())==d,('unrelated ROM modified',q)
    assert sha(rom.read_bytes())==digest
    deps=list((P/'src').glob('*'))+list((P/'tools').glob('*.py'))+list((P/'tests').glob('*.py'))+list((P/'tests').glob('*.lua'))
    deps += [ROOT/'tools/port_probe.py',ROOT/'tools/native_port_common.py',ROOT/'tools/directional_art.py',ROOT/'assets/mario-directional-sheet.png']
    receipt=dict(rom_sha256=digest,passed=True,verified_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),checks=checks,
                 dependencies={str(q.relative_to(ROOT)):sha(q.read_bytes())for q in deps if q.is_file()},
                 limits=['Native boxing adaptation, without platform gravity or jumping.','No full campaign, ending or physical cartridge verification.','Progression uses a staged third-knockdown finishing fireball; roster tests use the native fight loader.','Fireballs use background tiles and move on the native 8-pixel tile grid.'])
    (P/'dist/verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
    skill=ROOT/'tools/check_release.py';spec=importlib.util.spec_from_file_location('release',skill);release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
    kwargs=dict(base=Path(m['base_rom']),ips=P/'dist'/f'{name}.ips')
    release.check_release(rom,P/'build/manifest.json',P/'dist/verification.json',**kwargs)
    if a.install:install(P,name)
    report=release.check_release(rom,P/'build/manifest.json',P/'dist/verification.json',installed=INSTALL_DIR/f'{name}.nes'if a.install else None,**kwargs)
    (P/'build/release-check.json').write_text(json.dumps(report,indent=2)+'\n')
    for q,d in preserved.items():assert sha(q.read_bytes())==d,('unrelated ROM modified',q)
    (P/'build/delivery.json').write_text(json.dumps(dict(installed=a.install,sha256=digest,preserved_roms={str(q):d for q,d in preserved.items()}),indent=2)+'\n')
    print(('INSTALLED 'if a.install else'VERIFIED ')+name+' '+digest,flush=True)
def run(key,cmd):
    logs=P/'build/verification-logs';logs.mkdir(exist_ok=True);log=logs/(key+'.log')
    r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=75);log.write_text(r.stdout+'\n'+r.stderr)
    if r.returncode or 'FAIL 'in r.stdout or 'Error:'in r.stdout or 'PASS 'not in r.stdout:
        raise RuntimeError(key+' failed: '+str(log)+'\n'+r.stdout[-2500:]+r.stderr[-700:])
    return log
if __name__=='__main__':main()
