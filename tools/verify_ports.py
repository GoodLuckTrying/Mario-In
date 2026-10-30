from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,hashlib,json,subprocess,sys,time
BASE=Path(__file__).resolve().parents[1]
NAMES={'kungfu':'Mario in Kung Fu','snake':'Mario and Luigi in Snake Rattle n Roll'}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--game',choices=list(NAMES),action='append');args=parser.parse_args();selected=args.game or list(NAMES)
 subprocess.run([sys.executable,'tools/verify_native_ports.py'],cwd=BASE,check=True)
 for game in selected:
  if game=='kungfu':subprocess.run([sys.executable,'tools/audit_all_physics.py','--candidate','--game',game,'--require-match'],cwd=BASE,check=True,stdout=subprocess.DEVNULL)
 jobs=[]
 for game,count in [('kungfu',5),('snake',11)]:
  for stage in range(count):jobs.append((game,f'stage-{stage}','runtime',{'STAGE':stage}))
 jobs.append(('snake','solo','runtime',{'STAGE':0,'PLAYERS':1}))
 for stage in range(5):jobs.append(('kungfu',f'boss-{stage}','boss',{'STAGE':stage}))
 for stage in range(5):jobs.append(('kungfu',f'entrance-{stage}','entrance',{'STAGE':stage}))
 for mode in range(4):
  for method in ['select','down']:jobs.append(('kungfu',f'menu-{method}-{mode}','menu',{'MODE':mode,'METHOD':"'"+method+"'"}))
 for method in ['up','hold']:jobs.append(('kungfu',f'menu-{method}','menu',{'METHOD':"'"+method+"'"}))
 for stage in range(5):jobs.append(('kungfu',f'death-{stage}','death',{'STAGE':stage}))
 jobs.append(('kungfu','death-in-air','death',{'STAGE':0,'AIR':1}))
 jobs.append(('kungfu','death-game-over','death',{'STAGE':0,'LAST':1}))
 for stage in [0,4]:jobs.append(('kungfu',f'melee-{stage}','melee',{'STAGE':stage}))
 for stage in range(5):jobs.append(('kungfu',f'jump-background-{stage}','jump_background',{'STAGE':stage}))
 for stage,power in [(0,1),(0,2),(4,2)]:jobs.append(('kungfu',f'jump-stress-{stage}-{power}','jump_stress',{'STAGE':stage,'POWER':power}))
 for stage,power in [(0,0),(0,1),(0,2),(1,0),(1,1),(1,2),(2,2),(3,2)]:jobs.append(('kungfu',f'stairs-{stage}-{power}','stairs',{'STAGE':stage,'POWER':power}))
 jobs.append(('kungfu','video-combat-regressions','combat',{}))
 jobs.append(('kungfu','live-SMB1-jump-arcs','physics-audit',{}))
 jobs.append(('kungfu','final-ending','ending',{}))
 for p in [0,1]:
  jobs.append(('snake',f'tongue-{p}','tongue',{'PLAYER':p}))
  jobs.append(('snake',f'boss-fire-{p}','boss_fire',{'PLAYER':p}))
  jobs.append(('snake',f'manholes-{p}','manholes',{'PLAYER':p}))
  jobs.append(('snake',f'rooms-{p}','rooms',{'PLAYER':p}))
 for stage in [0,8]:jobs.append(('snake',f'directional-source-{stage}','directional',{'STAGE':stage}))
 for stage in range(11):jobs.append(('snake',f'motion-scroll-{stage}','motion_timing',{'STAGE':stage}))
 jobs.append(('snake','motion-scroll-solo','motion_timing',{'STAGE':0,'PLAYERS':1}))
 jobs.append(('snake','controller-facing','motion_facing',{}))
 jobs.append(('snake','fire-and-shared-palettes','palette_probe',{}))
 for stage in [0,4,8]:jobs.append(('snake',f'graphics-{stage}','graphics',{'STAGE':stage}))
 jobs=[j for j in jobs if j[0] in selected]
 def run(job):
  game,name,script,defs=job;root=BASE/game;logs=root/'build/verification';logs.mkdir(exist_ok=True)
  args=[sys.executable,'tools/port_probe.py',game,str(root/'tests'/f'{script}.lua'),'--rom',str(root/'dist'/f'{NAMES[game]}.nes')]
  if script=='directional':args+=['--timeout','90']
  for k,v in defs.items():args+=['--define',f'{k}={v}']
  start=time.time();r=subprocess.run(args,cwd=BASE,capture_output=True,text=True,timeout=110 if script=='directional'else 55)
  (logs/f'{name}.log').write_text(r.stdout+r.stderr)
  return game,{'name':name,'passed':r.returncode==0 and 'PASS ' in r.stdout and 'FAIL ' not in r.stdout,'seconds':round(time.time()-start,2)}
 results={g:[] for g in selected}
 with ThreadPoolExecutor(max_workers=2) as pool:
  for f in as_completed([pool.submit(run,j) for j in jobs]):
   game,item=f.result();results[game].append(item);print(game,item['name'],'PASS' if item['passed'] else 'FAIL',flush=True)
 for game in selected:
  name=NAMES[game]
  root=BASE/game;meta=json.loads((root/'build/manifest.json').read_text());rom=(root/'dist'/f'{name}.nes').read_bytes()
  assert all(x['passed'] for x in results[game]),f'{game}: see build/verification logs'
  original=Path('C:/nes')/('Kung Fu (Japan, USA) (En).nes' if game=='kungfu' else 'Snake Rattle n Roll (USA).nes')
  old=original.read_bytes();assert hashlib.sha256(old).hexdigest()==meta['base_sha256']
  assert hashlib.sha256(rom).hexdigest()==meta['output_sha256']
  patched={a for h in meta['hooks'] for a in range(h['address'],h['address']+h['length'])}
  for addr in range(0x8000,0x10000):
   if addr not in patched:assert old[16+addr-0x8000]==rom[16+addr-0x8000],hex(addr)
  patch=(root/'dist'/f'{name}.ips').read_bytes();assert patch[:5]==b'PATCH';out=bytearray(old);p=5
  while patch[p:p+3]!=b'EOF':
   offset=int.from_bytes(patch[p:p+3],'big');size=int.from_bytes(patch[p+3:p+5],'big');p+=5;assert size
   if offset+size>len(out):out.extend(bytes(offset+size-len(out)))
   out[offset:offset+size]=patch[p:p+size];p+=size
  assert out==rom
  cpu=json.loads((root/'build/cpu-verification.json').read_text());assert cpu['rom_sha256']==meta['output_sha256']
  if game=='kungfu':results[game].append({'name':'expanded SMB1 source movement comparison','passed':True})
  report={'rom_sha256':meta['output_sha256'],'passed':True,'checks':cpu['checks']+sorted(results[game],key=lambda x:x['name']),
   'original_unchanged':True,'ips_reconstructs_rom':True,'native_prg_outside_documented_hooks_unchanged':True,
   'limits':['Stage openings and deterministic integration fixtures were tested in Mesen; this is not a full unassisted campaign clear or a hardware test.']}
  (root/'dist/verification.json').write_text(json.dumps(report,indent=2))
  print(game,len(report['checks']),'checks passed',flush=True)
if __name__=='__main__':main()
