"""Verify exact candidates, write receipts, then optionally install both ports."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,datetime,hashlib,importlib.util,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import sha,install,SMB,INSTALL_DIR
NAMES={'megaman2':'Mario in Mega Man 2','metroid':'Mario in Metroid'}

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
 manifests={g:json.loads((ROOT/g/'build/manifest.json').read_text()) for g in NAMES}
 originals={Path(j['base_rom']):Path(j['base_rom']).read_bytes() for j in manifests.values()}
 existing={p:sha(p.read_bytes()) for p in INSTALL_DIR.glob('*.nes') if ('Mario' in p.name or 'Luigi' in p.name) and p.stem not in NAMES.values()}
 expected={g:sha((ROOT/g/'dist'/(name+'.nes')).read_bytes()) for g,name in NAMES.items()}
 for g,j in manifests.items():assert expected[g]==j['output_sha256']
 all_checks={g:[] for g in NAMES};dependencies={}
 jobs=[]
 for game in NAMES:
  jobs.append((game,'physics',[sys.executable,str(ROOT/game/'tools/audit_physics.py')],112,'Complete normal-land controller matches assembled SMB1 source (112 cases / 15,680 updates)'))
 for stage in range(8):
  jobs.append(('megaman2',f'stage-{stage}',probe('megaman2','megaman2/tests/gameplay.lua',f'STAGE={stage}'),1,f'Native stage {stage} menu entry, Mario CHR, health, repeated jumps/fireballs and pause/resume'))
 for game,script,key,name in [
  ('megaman2','megaman2/tests/intro.lua','intro','Full unskipped prologue, complete rooftop Mario and title CHR/VRAM timing'),
  ('megaman2','megaman2/tests/scenes.lua','scenes','Native post-victory weapon portrait, password and return, simultaneous native and Mario shots, blanked CHR uploads'),
  ('metroid','metroid/tests/arrival_and_shots.lua','arrival-and-shots','150 visible arrival frames; native horizontal/up shots plus independent bouncing balls; full native shot pool and pause'),
  ('metroid','metroid/tests/crowded_render.lua','crowded-render','Five ordinary enemies plus Mellows and live fireball objects preserve separate native/player rendering'),
  ('metroid','metroid/tests/stomp_approach.lua','stomp-approach','Real A-button jump and native crawler AI through stomp, bounce and native defeat'),
  ('megaman2','megaman2/tests/ladder.lua','ladder','Native ladder grab, climbing art, ladder shooting and drop/control handoff'),
  ('megaman2','megaman2/tests/swimming.lua','swimming','Real underwater checkpoint, swimming strokes, water art and running-to-water speed reset'),
  ('metroid','metroid/tests/gameplay.lua','gameplay','Native energy, jump heights, Boots, Morph Ball gating, bombs, missiles, beams, stomps, side/boss damage and pause'),
  ('metroid','metroid/tests/death.lua','death','Native injury, death animation, game-over and password flow without reset')]:
  jobs.append((game,key,probe(game,script),20 if key=='gameplay' else 1,name))
 for game in NAMES:
  jobs.append((game,'replay',probe(game,'tests/new_port_replay.lua',f'GAME="{game}"'),1500,'1,500-frame moving/shooting replay with native enemies, visible-VRAM and original mapper-write guards'))
 # CPU fixtures are shared and write one hash-bound report per candidate.
 r=subprocess.run([sys.executable,str(ROOT/'tools/check_new_port_cpu.py')],cwd=ROOT,capture_output=True,text=True,timeout=90)
 if r.returncode:raise RuntimeError(r.stdout+'\n'+r.stderr)
 print(r.stdout.strip(),flush=True)
 for game in NAMES:
  report=json.loads((ROOT/game/'build/cpu-verification.json').read_text());assert report['rom_sha256']==expected[game]
  all_checks[game]+=report['checks']
 with ThreadPoolExecutor(max_workers=4) as pool:
  futures={pool.submit(run_job,job):job for job in jobs}
  for future in as_completed(futures):
   game,key,command,cases,name=futures[future]
   log=future.result()
   all_checks[game].append(dict(name=name,cases=cases,passed=True,log=str(log.relative_to(ROOT)),log_sha256=sha(log.read_bytes())))
   print('PASS',game,key,flush=True)
 # No test or outside action may have changed an original or a candidate.
 for p,data in originals.items():assert p.read_bytes()==data,('original modified',p)
 for g,name in NAMES.items():assert sha((ROOT/g/'dist'/(name+'.nes')).read_bytes())==expected[g]
 for p,digest in existing.items():assert sha(p.read_bytes())==digest,('existing port changed',p)
 # Record the exact test and implementation dependencies as well as the ROM.
 sources=[ROOT/'tools/native_port_common.py',ROOT/'tools/build_port_references.py',ROOT/'tools/check_new_port_cpu.py',ROOT/'tools/verify_new_ports.py',ROOT/'tools/build.py',ROOT/'src/smb-land.inc',ROOT/'tests/new_port_replay.lua']
 for game in NAMES:
  sources_for_game=sources+list((ROOT/game/'src').glob('*'))+list((ROOT/game/'tools').glob('*.py'))+list((ROOT/game/'tests').glob('*.lua'))
  source_hashes={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sources_for_game if p.is_file()}
  report=dict(rom_sha256=expected[game],passed=True,verified_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    checks=all_checks[game],source_revision=manifests[game]['source_revision'],dependencies=source_hashes,
    replay=json.loads((ROOT/game/'build/replay-timing.json').read_text()),
    limits=['Campaign has not been cleared end to end.','Measured replay performance does not prove constant 60 Hz in every scene.'])
  (ROOT/game/'dist/verification.json').write_text(json.dumps(report,indent=2)+'\n')
 skill=ROOT/'tools/check_release.py'
 spec=importlib.util.spec_from_file_location('release',skill);release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
 for game,name in NAMES.items():
  p=ROOT/game
  # Check the patch reconstruction before permitting installation.
  check=release.check_release(p/'dist'/(name+'.nes'),p/'build/manifest.json',p/'dist/verification.json',
    base=Path(manifests[game]['base_rom']),smb=SMB,ips=p/'dist'/(name+'.ips'))
  assert check['passed']
 if args.install:
  for game,name in NAMES.items():install(ROOT/game,name)
 for game,name in NAMES.items():
  p=ROOT/game
  check=release.check_release(p/'dist'/(name+'.nes'),p/'build/manifest.json',p/'dist/verification.json',
    base=Path(manifests[game]['base_rom']),smb=SMB,ips=p/'dist'/(name+'.ips'),installed=INSTALL_DIR/(name+'.nes') if args.install else None)
  (p/'build/release-check.json').write_text(json.dumps(check,indent=2)+'\n')
  print(('INSTALLED ' if args.install else 'VERIFIED ')+name+' '+expected[game],flush=True)
 for p,digest in existing.items():assert sha(p.read_bytes())==digest,('existing port changed during install',p)
 for p,data in originals.items():assert p.read_bytes()==data
 delivery=dict(installed=args.install,roms={g:dict(name=NAMES[g],sha256=expected[g]) for g in NAMES},preserved_existing_roms={str(p):v for p,v in existing.items()},preserved_originals={str(p):sha(v) for p,v in originals.items()})
 (ROOT/'build/megaman2-metroid-delivery.json').write_text(json.dumps(delivery,indent=2)+'\n')

def probe(game,script,define=None):
 command=[sys.executable,str(ROOT/'tools/port_probe.py'),game,str(ROOT/script),'--rom',str(ROOT/game/'dist'/(NAMES[game]+'.nes')),'--timeout','55']
 if define:command+=['--define',define]
 return command

def run_job(job):
 game,key,command,cases,name=job
 out=ROOT/game/'build/verification-logs';out.mkdir(exist_ok=True)
 result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=100)
 path=out/(key+'.log');path.write_text(result.stdout+'\n'+result.stderr)
 if result.returncode or 'FAIL ' in result.stdout or 'Error:' in result.stdout:
  raise RuntimeError(f'{game}/{key} failed; see {path}\n'+result.stdout[-4000:]+'\n'+result.stderr[-2000:])
 if key!='physics' and 'PASS ' not in result.stdout:raise RuntimeError('Missing test completion: '+str(path))
 return path
if __name__=='__main__':main()
