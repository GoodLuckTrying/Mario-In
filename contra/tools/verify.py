"""Run native emulator replays and bind the results to the delivered ROM."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,hashlib,json,re,subprocess,sys,time,zlib
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--reuse-run-log',type=Path);options=parser.parse_args()
 passed_before=set()
 if options.reuse_run_log:
  passed_before=set(re.findall(r'^([\w-]+) PASS$',options.reuse_run_log.read_text(),re.M))
 rom_path=ROOT/'dist/Mario and Luigi in Contra.nes'
 file_crc=f'File CRC32: 0x{zlib.crc32(rom_path.read_bytes()):08X}'
 logs=ROOT/'build/verification';logs.mkdir(exist_ok=True)
 (ROOT/'build/physics-audit').mkdir(exist_ok=True)
 subprocess.run([sys.executable,str(ROOT/'tools/audit_physics.py'),'--candidate','--require-match'],check=True,stdout=subprocess.DEVNULL)
 jobs=[('physics',['tools/verify_physics.py']),('expanded-source-physics',['tools/audit_physics.py','--candidate','--require-match'])]
 jobs.append(('native-collision-equivalence',['tools/verify_collision.py']))
 jobs.append(('source-sprite-pixels',['tools/verify_sprites.py']))
 jobs.append(('source-rifle-aim',['tools/verify_rifle_aim.py']))
 jobs.append(('source-base-art',['tools/verify_base_art.py']))
 jobs.append(('native-player-crouch-box',['tools/verify_player_box.py']))
 jobs.append(('source-title-and-blink-pixels',['tools/verify_title.py']))
 def replay(name,script,**defs):
  args=['tools/run_mesen.py','tests/'+script+'.lua']
  if script=='boss-jungle':args+=['--timeout','45']
  if script in ['demo-cycle','title-demo-transition']:args+=['--timeout','50']
  if script=='demo-start':args+=['--timeout','40']
  for k,v in defs.items():args+=['--define',k+'='+str(v)]
  jobs.append((name,args))
 replay('supplied-title-hardware','title-art')
 replay('independent-title-blinks','title-blink')
 replay('simultaneous-title-blinks','title-blink',SIMULTANEOUS='true')
 replay('title-demo-transition-pixels','title-demo-transition')
 replay('title-demo-transition-coop-pixels','title-demo-transition',COOP='true')
 for power in range(3):
  for left in ['false','true']:
   replay(f'water-entry-{power}-{left}','water-entry',POWER=power,LEFT=left)
 for coop in ['false','true']:
  for demo in ['false','true']:
   replay(f'lives-screen-{coop}-{demo}','lives-screen',COOP=coop,AFTER_DEMO=demo)
 replay('opening-supplies','supplies');replay('coop','coop');replay('fire-native-kill','fire-hit')
 replay('demo-players','demo')
 replay('rifle-hardware','rifle-sprites')
 for power in range(3):replay(f'rifle-aim-{power}','rifle-aim',POWER=power)
 for stage in [1,3]:replay(f'rifle-base-{stage}','rifle-base',STAGE=stage)
 for power in [0,1]:replay(f'rifle-swimming-{power}','rifle-sprites',WATER='true',POWER=power)
 replay('demo-complete-cycle','demo-cycle')
 for coop in ['false','true']:
  for mode in ['natural','start','select']:
   replay(f'demo-start-{mode}-{coop}','demo-start',END_MODE="'"+mode+"'",COOP=coop)
 for stage in [0,1,5,6]:replay(f'performance-{stage}','performance',STAGE=stage)
 for stage in range(7):replay(f'exit-{stage}','transitions',STAGE=stage)
 for mode in ['no-up','outside','wrong','held-a']:replay('cheat-'+mode,'cheat',MODE="'"+mode+"'")
 for player in [0,1]:
  replay(f'live-source-physics-{player}','physics-audit',PLAYER=player)
  for mode in ['side','top','perspective']:replay(f'boss-shape-{player}-{mode}','boss-stomps',PLAYER=player,MODE="'"+mode+"'")
  for power in range(3):
   replay(f'landing-pose-{player}-{power}','landing-pose',PLAYER=player,POWER=power)
   for mode in ['ledge','tunnel','cart','edge']:replay(f'late-terrain-{player}-{power}-{mode}','late-collision',PLAYER=player,POWER=power,MODE="'"+mode+"'")
   for mode in ['flame','spikes']:replay(f'hazard-{player}-{power}-{mode}','hazards',PLAYER=player,POWER=power,MODE="'"+mode+"'")
  for power in [0,2]:replay(f'cheat-{player}-{power}','cheat',PLAYER=player,POWER=power)
  for option in ['HOLD_B','REVERSE']:
   replay(f'braking-{player}-{option}','braking',PLAYER=player,**{option:'true'})
  replay(f'braking-{player}','braking',PLAYER=player)
  replay(f'pickups-{player}','abilities',PLAYER=player)
  for weapon in range(5):
   for power in [0,2]:replay(f'weapon-{player}-{weapon}-{power}','weapons',PLAYER=player,WEAPON=weapon,POWER=power)
   replay(f'weapon-base-{player}-{weapon}','weapons',PLAYER=player,WEAPON=weapon,POWER=2,STAGE=1+player*2)
  replay(f'weapon-super-{player}','weapons',PLAYER=player,WEAPON=3,POWER=1)
  replay(f'boss-fire-{player}','boss-jungle',PLAYER=player,FIRE_ONLY='true')
  replay(f'boss-small-gun-{player}','boss-jungle',PLAYER=player,POWER=0)
  for power in range(3):
   for left in ['false','true']:
    for run in ['false','true']:
     replay(f'shore-{player}-{power}-{left}-{run}','water-shore',PLAYER=player,POWER=power,LEFT=left,RUN=run,PHASE=power*7+(run=='true'))
   for mode in ['solid','under']:
    replay(f'shore-{mode}-{player}-{power}','water-shore',PLAYER=player,POWER=power,MODE="'"+mode+"'",RUN='true',LEFT=str(player==1).lower())
   replay(f'drop-{player}-{power}','drop-through',PLAYER=player,POWER=power,PHASE=power*7)
   replay(f'stomp-pair-{player}-{power}','combat',PLAYER=player,POWER=power,PAIR='true')
   replay(f'damage-{player}-{power}','combat',PLAYER=player,POWER=power,MODE="'damage'")
   replay(f'overhead-{player}-{power}','combat',PLAYER=player,POWER=power,MODE="'overhead'")
  for mode in ['ceiling','high-wall']:
   replay(f'shore-{mode}-{player}','water-shore',PLAYER=player,POWER=2,MODE="'"+mode+"'",LEFT=str(player==1).lower())
  replay(f'bullet-{player}','combat',PLAYER=player,MODE="'bullet'")
  replay(f'capsule-{player}','combat',PLAYER=player,MODE="'capsule'")
  replay(f'retry-{player}','combat',PLAYER=player,POWER=0,MODE="'damage'",RETRY='true')
  for stage in [0,1,3]:replay(f'fire-{player}-{stage}','fire',PLAYER=player,STAGE=stage)
  for mode in ['solid','no-lower','blocked']:
   replay(f'drop-{mode}-{player}','drop-through',PLAYER=player,POWER=2,MODE="'"+mode+"'")
  replay(f'drop-vertical-{player}','drop-through',PLAYER=player,POWER=1,STAGE=2,PHASE=15)
 for stage in [0,1]:replay(f'weapons-coop-{stage}','weapons-coop',STAGE=stage)
 replay('water-jungle','water-jungle')
 replay('bridges-solo','bridges')
 replay('bridges-signed-solo','bridges',SIGNED_EDGE='true')
 replay('bridges-coop','bridges',COOP='true',POWER=2)
 for stage in [1,3]:
  replay(f'base-advance-{stage}','base-advance',STAGE=stage)
  for player in [0,1]:replay(f'base-mushroom-{stage}-{player}','base-mushroom',STAGE=stage,PLAYER=player)
  replay(f'base-palettes-{stage}','palette',STAGE=stage)
 for vertical in ['false','true']:replay('camera-'+vertical,'camera',VERTICAL=vertical)
 for power in range(3):
  replay('water-'+str(power),'water',POWER=power)
  replay('jump-top-'+str(power),'jump-top',POWER=power)
 for stage in range(8):
  for power in (range(3) if stage==0 else [1]):replay(f'video-{stage}-{power}','video',STAGE=stage,POWER=power)
 def check(job):
  name,args=job;start=time.time()
  path=logs/(name+'.log')
  if name in passed_before and args[0]=='tools/run_mesen.py' and path.exists():
   data=path.read_text()
   dependencies=[rom_path,ROOT/'build/manifest.json',ROOT/args[0],ROOT/args[1]]
   if file_crc in data and all(item.stat().st_mtime_ns<=path.stat().st_mtime_ns for item in dependencies):
    return {'name':name,'passed':True,'seconds':0,'reused_same_rom':True}
  r=subprocess.run([sys.executable,*args],cwd=ROOT,capture_output=True,text=True,timeout=60)
  path.write_text(r.stdout+r.stderr)
  return {'name':name,'passed':r.returncode==0,'seconds':round(time.time()-start,2)}
 results=[]
 with ThreadPoolExecutor(max_workers=4) as pool:
  for future in as_completed([pool.submit(check,j) for j in jobs]):
   item=future.result();results.append(item);print(item['name'],'PASS' if item['passed'] else 'FAIL',flush=True)
 assert all(r['passed'] for r in results),'See failing emulator logs in build/verification'
 manifest=json.loads((ROOT/'build/manifest.json').read_text())
 base=Path('C:/nes/Contra (USA).nes').read_bytes();smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
 rom=(ROOT/'dist/Mario and Luigi in Contra.nes').read_bytes()
 assert hashlib.sha256(base).hexdigest()==manifest['base_sha256']
 assert hashlib.sha256(smb).hexdigest()==manifest['smb_sha256']
 assert (ROOT/'build/native.nes').read_bytes()[16:]==base[16:],'Native reference must exactly match all original PRG bytes'
 patch=(ROOT/'dist/Mario and Luigi in Contra.ips').read_bytes();assert patch[:5]==b'PATCH'
 applied=bytearray(base);p=5
 while patch[p:p+3]!=b'EOF':
  offset=int.from_bytes(patch[p:p+3],'big');size=int.from_bytes(patch[p+3:p+5],'big');p+=5
  assert size
  if offset+size>len(applied):applied.extend(bytes(offset+size-len(applied)))
  applied[offset:offset+size]=patch[p:p+size];p+=size
 assert applied==rom,'IPS must reconstruct the ROM exactly'
 report={'rom_sha256':hashlib.sha256(rom).hexdigest(),'passed':True,'checks':sorted(results,key=lambda x:x['name']),
         'physics':json.loads((ROOT/'build/physics-results.json').read_text()),'originals_unchanged':True,'ips_reconstructs_rom':True,
         'native_prg_matches_base':True,'limits':['Integration fixtures are not a full unassisted campaign clear.','All eight stage openings are tested; the full campaign and ending have not been cleared.','Dense two-player volleys can still slow down; rifle sprites and recoil have a measured CPU cost versus the previous build.','The exact live physics trace and controlled snow performance fixtures disable DMC before controller reads to isolate the native DMC pad-read glitch; other replays retain audio. The snow fixture pins its RNG/frame sequence and must meet the pre-title ROM benchmark of 429 updates per 600 frames; its unpinned enemy/weather sequence changes when title timing changes.']}
 (ROOT/'dist/verification.json').write_text(json.dumps(report,indent=2))
 print('All',len(results),'checks passed; originals unchanged; IPS verified.',flush=True)
if __name__=='__main__':main()
