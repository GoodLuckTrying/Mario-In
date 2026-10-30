"""Hash-bound emulator/CPU verification for the Karnov and Rygar ports."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from check_release import apply_ips

def main(game):
 p=ROOT/game;name='Mario in '+game.capitalize();rom=p/'dist'/f'{name}.nes';m=json.loads((p/'build/manifest.json').read_text());sha=lambda b:hashlib.sha256(b).hexdigest()
 data=rom.read_bytes();base=Path(m['base_rom']).read_bytes();patch=(p/'dist'/f'{name}.ips').read_bytes()
 assert sha(data)==m['output_sha256'] and sha(base)==m['base_sha256']
 assert sha(Path('C:/nes/Super Mario Bros. (World).nes').read_bytes())==m['smb_sha256']
 assert apply_ips(base,patch)==data
 if game=='karnov':
  assert data[16+262144:16+262144+65536]==base[16+131072:],'all original background/enemy CHR retained'
 else:
  for bank,regions in [(0,[(0x440,16384)]),(2,[(0,0x800),(0xC40,16384)])]:
   for lo,hi in regions:assert data[16+bank*16384+lo:16+bank*16384+hi]==base[16+bank*16384+lo:16+bank*16384+hi],'native weapon/enemy/background CHR preserved'
 logs=p/'build/verification';logs.mkdir(exist_ok=True)
 jobs=[('source-physics',['tools/verify_land_pair.py',game]),('native-combat',['tools/verify_pair_combat.py',game])]
 jobs.append(('native-state-adapters',['tools/verify_pair_state.py',game]))
 def replay(label,script,**defs):
  args=['tools/port_probe.py',game,script,'--rom',str(rom),'--timeout','45']
  for key,val in defs.items():args.extend(['--define',key+'='+str(val)])
  jobs.append((label,args))
 for fixture in ['fire','movement','health']:replay(fixture,f'{game}/tests/{fixture}.lua')
 replay('moving-camera-fire','tools/tests/pair_fire_camera.lua')
 if game=='karnov':
  for stage in range(9):replay(f'graphics-stage-{stage}',f'{game}/tests/graphics.lua',STAGE=stage)
 else:
  replay('graphics-side',f'{game}/tests/graphics.lua')
  for entry in [0,12,20]:replay(f'graphics-overhead-{entry}',f'{game}/tests/graphics.lua',ENTRY=entry)
  for entry in [24,42,52,60]:replay(f'graphics-side-{entry}',f'{game}/tests/graphics.lua',ENTRY=entry,SIDE='true')
 def check(job):
  label,args=job;t=time.time();r=subprocess.run([sys.executable,*args],cwd=ROOT,capture_output=True,text=True,timeout=65)
  (logs/(label+'.log')).write_text(r.stdout+r.stderr)
  return dict(name=label,passed=r.returncode==0,seconds=round(time.time()-t,2))
 rows=[dict(name='base-inputs-IPS-and-native-graphics-integrity',passed=True)]
 with ThreadPoolExecutor(max_workers=3)as pool:
  for result in as_completed([pool.submit(check,j)for j in jobs]):
   row=result.result();rows.append(row);print(game,row['name'],'PASS'if row['passed']else'FAIL',flush=True)
 assert all(row['passed']for row in rows),'See failing logs in '+str(logs)
 receipt=dict(rom_sha256=sha(data),passed=True,checks=rows,originals_unchanged=True,ips_reconstructs_rom=True,
  physics=json.loads((p/'build/physics-results.json').read_text()),combat=json.loads((p/'build/combat-results.json').read_text()),
  native_state=json.loads((p/'build/state-results.json').read_text()),
  limits=['Mesen 2 and isolated 6502 instruction fixtures; no physical-console test or complete campaign clear.','Native health, collision state machines, equipment and scripted/overhead movement are intentional host adaptations.','Controlled enemy contacts and native stage/entry loading are used to exercise injury, death and graphics without an unassisted campaign replay.','The source motor matches isolated SMB1 cases; native terrain, camera cadence and required traversal states remain host-specific.'])
 (p/'dist/verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print('PASS',game,len(rows),'checks bound to',receipt['rom_sha256'],flush=True)
if __name__=='__main__':main(sys.argv[1])
