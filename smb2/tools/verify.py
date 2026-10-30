from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
import hashlib,json,subprocess,sys,time
from build import ROOT,BASE,SMB,SHA,SMBSHA,NAME
def main():
    subprocess.run([sys.executable,str(ROOT/'tools/verify_cpu.py')],check=True)
    subprocess.run([sys.executable,str(ROOT.parent/'tools/audit_all_physics.py'),'--candidate','--game','smb2','--require-match'],check=True,stdout=subprocess.DEVNULL)
    jobs=[]
    def add(name,script,**defs):jobs.append((name,script,defs))
    add('two-brother-menu','menu')
    for char in [0,3]:
        add(f'opening-controller-{char}','runtime',CHAR=char)
        add(f'pause-{char}','pause',CHAR=char,AREA=1)
        add(f'mushroom-{char}','mushroom',CHAR=char)
        add(f'small-palette-reload-{char}','palette-reload',CHAR=char)
        for hold in [1,25]:add(f'live-SMB1-arc-{char}-{hold}','physics-audit',CHAR=char,HOLD=hold)
        for hp in [15,31,47,63]:add(f'hearts-{char}-{hp}','health',CHAR=char,HP=hp)
        for small in [False,True]:
            add(f'walk-cycle-{char}-{small}','walk-cycle',CHAR=char,SMALL=small)
            for held in [False,True]:add(f'charged-jump-{char}-{small}-{held}','crouch-jump',CHAR=char,SMALL=small,HELD=held)
            for left in [False,True]:add(f'climb-{char}-{small}-{left}','climb',CHAR=char,SMALL=small,LEFT=left)
            for mode in ['stand','walk','jump','pickup']:add(f'enemy-head-{char}-{small}-{mode}','enemy-head',CHAR=char,SMALL=small,MODE=mode)
            add(f'moving-enemy-head-{char}-{small}','enemy-head',CHAR=char,SMALL=small,MOVING=True)
            add(f'pluck-{char}-{small}','pluck',CHAR=char,SMALL=small)
            add(f'door-{char}-{small}','door',CHAR=char,SMALL=small)
            for left in [False,True]:add(f'carry-{char}-{small}-{left}','carry',CHAR=char,SMALL=small,LEFT=left)
            for world in range(7):add(f'world-hardware-{world}-{char}-{small}','hardware',WORLD=world,CHAR=char,SMALL=small)
        for mode in ['hit','bounce']:add(f'fire-{char}-{mode}','fire',CHAR=char,AREA=1,MODE=mode)
        for mode in ['left','right','spawn-left','spawn-right','page','wrap-left','wrap-right','top','bottom','bottom-edge','y-page']:
            add(f'fire-bounds-{char}-{mode}','fire-bounds',CHAR=char,MODE=mode)
    logs=ROOT/'build/verification';logs.mkdir(exist_ok=True)
    def replay(job):
        name,script,defs=job;start=time.time()
        args=[sys.executable,str(ROOT.parent/'tools/port_probe.py'),'smb2',str(ROOT/'tests'/f'{script}.lua'),'--rom',str(ROOT/'dist'/f'{NAME}.nes'),'--timeout','45']
        for k,v in defs.items():args+=['--define',k+'='+('true'if v is True else'false'if v is False else repr(v))]
        try:
            p=subprocess.run(args,capture_output=True,text=True,timeout=55);out=p.stdout+p.stderr
            ok=p.returncode==0 and'PASS 'in out and'FAIL 'not in out
        except Exception as e:out=str(e);ok=False
        (logs/(name+'.log')).write_text(out)
        return {'name':name,'passed':ok,'seconds':round(time.time()-start,2)}
    checks=[]
    with ThreadPoolExecutor(max_workers=4)as pool:
        for result in as_completed([pool.submit(replay,j)for j in jobs]):
            item=result.result();checks.append(item);print(item['name'],'PASS'if item['passed']else'FAIL',flush=True)
    assert all(c['passed']for c in checks),'Inspect smb2/build/verification'
    rom=(ROOT/'dist'/f'{NAME}.nes').read_bytes();old=BASE.read_bytes();meta=json.loads((ROOT/'build/manifest.json').read_text());sha=hashlib.sha256(rom).hexdigest()
    assert sha==meta['output_sha256']and hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(SMB.read_bytes()).hexdigest()==SMBSHA
    assert (ROOT/'build/native.nes').read_bytes()[16:]==old[16:]
    # All original gameplay CHR and enemy/background palettes are preserved.
    for bank in range(128):
        if bank!=48:assert rom[0x20010+bank*1024:0x20010+(bank+1)*1024]==old[0x20010+bank*1024:0x20010+(bank+1)*1024]
    patch=(ROOT/'dist'/f'{NAME}.ips').read_bytes();assert patch[:5]==b'PATCH';i=5;out=bytearray(old)
    while patch[i:i+3]!=b'EOF':
        a=int.from_bytes(patch[i:i+3],'big');n=int.from_bytes(patch[i+3:i+5],'big');i+=5;assert n
        if a+n>len(out):out.extend(bytes(a+n-len(out)))
        out[a:a+n]=patch[i:i+n];i+=n
    assert out==rom
    checks.append({'name':'expanded SMB1 source movement comparison','passed':True})
    checks.append({'name':'original hashes, exact native reference, original gameplay CHR and IPS reconstruction','passed':True})
    cpu=json.loads((ROOT/'build/cpu-verification.json').read_text());assert cpu['rom_sha256']==sha;checks+=cpu['checks']
    receipt={'rom_sha256':sha,'passed':True,'checks':sorted(checks,key=lambda c:c['name']),'originals_unchanged':True,'ips_reconstructs_rom':True,'limits':['Actor/position fixtures isolate mechanics. These tests are not a full unassisted campaign or physical NES test.']}
    (ROOT/'dist/verification.json').write_text(json.dumps(receipt,indent=2))
    print('All',len(checks),'checks passed; originals unchanged; exact IPS verified.',flush=True)
if __name__=='__main__':main()
