"""Verify the exact Ghosts candidate, record evidence and optionally install."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,datetime,importlib.util,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'ghosts';sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import sha,SMB,install
NAME='Mario in Ghosts n Goblins'
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');a=parser.parse_args()
 meta=json.loads((P/'build/manifest.json').read_text());rom=P/'dist'/(NAME+'.nes');digest=sha(rom.read_bytes());assert digest==meta['output_sha256']
 preserved={p:sha(p.read_bytes())for p in INSTALL_DIR.glob('*.nes')if ('Mario' in p.name or 'Luigi' in p.name)and p.stem!=NAME}
 originals={Path(meta['base_rom']):meta['base_sha256'],SMB:meta['smb_sha256']}
 jobs=[('physics',[sys.executable,str(P/'tools/audit_physics.py')],'Source-assembled SMB1 motion, both forms and directions, 272 cases / 38,080 updates'),('cpu',[sys.executable,str(P/'tools/check_cpu.py')],'Native OAM/CHR ownership, ordinary stomps, excluded enemies, independent shots and world seams')]
 for n in ('menus','hud','gameplay','fire_bounce','combat','ladder','two_players','demo','progression','timing'):
  defs=['IS_CANDIDATE=true']if n=='timing'else[]
  jobs.append((n,probe(n,defs),{
   'gameplay':'Native opening, complete streamed CHR, walking, full jump, crouch and five native weapon types with private fireballs',
   'fire_bounce':'Several actual native terrain collisions: short fireball apex and bounded return to the floor',
   'menus':'Small Mario title selector and separate loading/lives actor with refreshed complete CHR after scene loads',
   'hud':'Original score/time font and displayed HUD sprite palettes survive Mario streaming, running, jumping and firing',
   'combat':'A-button zombie stomp with native AI, adjacent protection, native side hit/shrink, armor pickup and lethal hit/respawn',
   'ladder':'Actual native map ladder, both climbing poses, ladder exit and SMB control handoff',
   'two_players':'Native Select/Start two-player mode, P1 life loss/turn change, P2 controller and fresh Fire Mario state',
   'demo':'Attract mode renders Mario and exits to a playable new game without reset',
   'progression':'Native boss finishing hit, defeat, staged native key pickup, door script and actual next-stage load',
   'timing':'1,600-video-frame movement/shot replay; VRAM timing, rendering restoration before visible scanlines and NMI stack headroom'}[n]))
 for kind in (12,13,14):
  for form in (0,32):jobs.append((f'platform-{kind}-{form}',probe('platforms',[f'KIND={kind}',f'FORM={form}']),f'Native moving platform {kind}, form {form}: grounded feet, carry, walking pose, jump-off and displayed CHR/palettes'))
 for stage in range(7):jobs.append((f'stage-{stage}',probe('stage',[f'STAGE={stage}']),f'Native stage {stage} checkpoint load, complete Mario CHR, both attack pools and clean visible VRAM timing'))
 jobs.append(('original-timing',probe('timing',['IS_CANDIDATE=false'],Path(meta['base_rom'])),'Original-ROM rendering timing baseline'))
 checks=[]
 with ThreadPoolExecutor(max_workers=3)as pool:
  fs={pool.submit(run,key,cmd):(key,name)for key,cmd,name in jobs}
  for future in as_completed(fs):
   key,name=fs[future];path=future.result();checks.append(dict(name=name,passed=True,log=str(path.relative_to(ROOT)),log_sha256=sha(path.read_bytes())));print('PASS',key,flush=True)
 cpu=json.loads((P/'build/cpu-verification.json').read_text());assert cpu['rom_sha256']==digest;checks+=cpu['checks']
 physics=json.loads((P/'build/physics-audit/results.json').read_text());assert physics['candidate_sha256']==digest and physics['matching']==physics['cases']
 timing=json.loads((P/'build/candidate-timing.json').read_text());assert timing['max_reenable_scanline']<261 and timing['late_vram']==0
 for p,d in {**preserved,**originals}.items():assert sha(p.read_bytes())==d,('preserved ROM changed',p)
 assert sha(rom.read_bytes())==digest
 deps=list((P/'src').glob('*'))+list((P/'tools').glob('*.py'))+list((P/'tests').glob('*.lua'))+[ROOT/x for x in ('tools/port_probe.py','tools/native_port_common.py','tools/build.py','tools/audit_all_physics.py','contra/tools/audit_physics.py','src/smb-land.inc','vendor/smb1base/src/player.s','vendor/smb1base/src/common.s')]
 receipt=dict(rom_sha256=digest,passed=True,verified_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_revision=meta['source_revision'],checks=checks,physics=dict(cases=physics['cases'],updates=physics['updates']),timing=timing,dependencies={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in deps if p.is_file()},limits=['No full campaign or ending clear.','Targeted fixtures seed native actors/checkpoints; the boss fixture begins one hit from defeat and stages the native key.','Native coroutine/render cadence remains; elapsed-frame physics does not establish constant 60 Hz rendering.','Added NES 2.0 work RAM is required; physical hardware untested.'])
 (P/'dist/verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
 skill=ROOT/'tools/check_release.py';sp=importlib.util.spec_from_file_location('release',skill);release=importlib.util.module_from_spec(sp);sp.loader.exec_module(release)
 kwargs=dict(base=Path(meta['base_rom']),smb=SMB,ips=P/'dist'/(NAME+'.ips'))
 release.check_release(rom,P/'build/manifest.json',P/'dist/verification.json',**kwargs)
 if a.install:install(P,NAME)
 report=release.check_release(rom,P/'build/manifest.json',P/'dist/verification.json',installed=INSTALL_DIR/(NAME+'.nes')if a.install else None,**kwargs)
 (P/'build/release-check.json').write_text(json.dumps(report,indent=2)+'\n')
 for p,d in {**preserved,**originals}.items():assert sha(p.read_bytes())==d,('ROM changed during install',p)
 (P/'build/delivery.json').write_text(json.dumps(dict(installed=a.install,sha256=digest,preserved_existing_roms={str(p):d for p,d in preserved.items()},preserved_originals={str(p):d for p,d in originals.items()}),indent=2)+'\n')
 print(('INSTALLED 'if a.install else'VERIFIED ')+NAME+' '+digest,flush=True)
def probe(name,defs=None,rom=None):
 cmd=[sys.executable,str(ROOT/'tools/port_probe.py'),'ghosts',str(P/'tests'/(name+'.lua')),'--rom',str(rom or P/'dist'/(NAME+'.nes')),'--timeout','55']
 for d in defs or []:cmd+=['--define',d]
 return cmd
def run(key,cmd):
 p=P/'build/verification-logs';p.mkdir(exist_ok=True);out=p/(key+'.log');r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=90);out.write_text(r.stdout+'\n'+r.stderr)
 if r.returncode or 'FAIL 'in r.stdout or 'Error:'in r.stdout:raise RuntimeError(key+' failed; '+str(out)+'\n'+r.stdout[-2500:]+r.stderr[-1200:])
 if key not in ('physics',)and'PASS 'not in r.stdout:raise RuntimeError('Missing completion: '+str(out))
 return out
if __name__=='__main__':main()
