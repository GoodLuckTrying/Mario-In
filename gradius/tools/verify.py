from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
def main():
 logs=ROOT/'build/verification';logs.mkdir(exist_ok=True)
 jobs=[('6502-fireball-physics',['tools/verify_cpu.py'])]
 def replay(name,script,**defs):
  args=['tools/run_mesen.py','tests/'+script+'.lua']
  for k,v in defs.items():args+=['--define',k+'='+str(v)]
  jobs.append((name,args))
 replay('boot-flight-render-performance','runtime')
 replay('title-pointer-and-selector','title')
 replay('native-alternating-mario-luigi','two-player')
 replay('controller-fireballs-native-waves','combat')
 replay('visible-attract-demo','demo')
 replay('swimming-animation','swim')
 replay('busy-frame-rendering','lag')
 for p in [0,1]:replay('mario-options-'+str(p),'options',PLAYER=p)
 for stage in range(7):replay('full-fireball-load-'+str(stage),'stress',STAGE=stage)
 for p in [0,1]:
  for options in [0,2]:replay(f'double-independent-{p}-{options}','double',PLAYER=p,OPTIONS=options)
 for p in [0,1]:
  for speed in [0,4,8]:replay(f'gravity-lift-{p}-{speed}','float',PLAYER=p,SPEED=speed)
 for p in [0,1]:replay('cheat-controller-'+str(p),'cheat',PLAYER=p)
 for mode in ['no-up','outside','wrong','held-a']:replay('cheat-'+mode,'cheat',MODE="'"+mode+"'")
 for inv in [0,1]:
  for kind in ['enemy','bullet','terrain']:replay(f'damage-{kind}-{inv}','damage',INV=inv,KIND="'"+kind+"'")
 for weapon in range(3):
  for options in [0,2]:replay(f'weapon-{weapon}-{options}','weapons',WEAPON=weapon,OPTIONS=options,MISSILE=1)
 for stage in range(7):replay('stage-'+str(stage),'stage',STAGE=stage)
 def check(job):
  name,args=job;start=time.time()
  r=subprocess.run([sys.executable,*args],cwd=ROOT,capture_output=True,text=True,timeout=50)
  (logs/(name+'.log')).write_text(r.stdout+r.stderr)
  return {'name':name,'passed':r.returncode==0,'seconds':round(time.time()-start,2)}
 results=[]
 with ThreadPoolExecutor(max_workers=3) as pool:
  for future in as_completed([pool.submit(check,j) for j in jobs]):
   item=future.result();results.append(item);print(item['name'],'PASS' if item['passed'] else 'FAIL',flush=True)
 assert all(r['passed'] for r in results),'See build/verification logs'
 manifest=json.loads((ROOT/'build/manifest.json').read_text())
 base=Path('C:/nes/Gradius (USA).nes').read_bytes();smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes();rom=(ROOT/'dist/Mario in Gradius.nes').read_bytes()
 assert hashlib.sha256(base).hexdigest()==manifest['base_sha256'] and hashlib.sha256(smb).hexdigest()==manifest['smb_sha256']
 patched={a for h in manifest['hooks'] for a in range(h['address'],h['address']+h['length'])}
 for address in range(0x8000,0x10000):
  if address not in patched:assert base[16+address-0x8000]==rom[16+address-0x8000],hex(address)
 # Only player and normal/double projectile pairs change. Original background
 # and enemy tiles, and the sprite-zero pattern, remain byte-exact.
 for bank in range(12):
  for tile in range(512):
   if tile>=256 and (tile-256)&0xfe in manifest['chr_pairs']:continue
   at=0x8010+bank*8192+tile*16;original_at=0x8010+(bank%4)*8192+tile*16
   assert base[original_at:original_at+16]==rom[at:at+16],(bank,tile)
 title=manifest['title_chr_bank']
 assert rom[0x8010+title*8192:0x8010+(title+1)*8192]==base[0x8010+3*8192:0x8010+4*8192]
 patch=(ROOT/'dist/Mario in Gradius.ips').read_bytes();assert patch[:5]==b'PATCH'
 applied=bytearray(base);p=5
 while patch[p:p+3]!=b'EOF':
  offset=int.from_bytes(patch[p:p+3],'big');size=int.from_bytes(patch[p+3:p+5],'big');p+=5;assert size
  if offset+size>len(applied):applied.extend(bytes(offset+size-len(applied)))
  applied[offset:offset+size]=patch[p:p+size];p+=size
 assert applied==rom,'IPS must reconstruct the ROM exactly'
 report={'rom_sha256':hashlib.sha256(rom).hexdigest(),'passed':True,'checks':sorted(results,key=lambda x:x['name']),
  'cpu':json.loads((ROOT/'build/cpu-results.json').read_text()),'originals_unchanged':True,'ips_reconstructs_rom':True,'native_background_and_enemy_chr_unchanged':True,
  'limits':['Stage openings and integration fixtures are tested; this is not a full unassisted campaign clear.']}
 (ROOT/'dist/verification.json').write_text(json.dumps(report,indent=2))
 print('All',len(results),'checks passed; originals unchanged; IPS verified.',flush=True)
if __name__=='__main__':main()
