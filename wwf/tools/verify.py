from pathlib import Path
import argparse,concurrent.futures,hashlib,json,subprocess,sys,time,zlib
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT.parent
NAME='Mario and Luigi in WWF WrestleMania'
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--reuse-passed',action='store_true');options=parser.parse_args()
 prior=json.loads((ROOT/'dist/verification.json').read_text())if options.reuse_passed else{}
 from verify_cpu import run
 started=time.time();checks=run();rom=ROOT/'dist'/f'{NAME}.nes';data=rom.read_bytes();meta=json.loads((ROOT/'build/manifest.json').read_text())
 old=Path('C:/nes/WWF WrestleMania (USA).nes').read_bytes()
 assert hashlib.sha256(old).hexdigest()==meta['base_sha256']
 assert hashlib.sha256(data).hexdigest()==meta['output_sha256']
 passed_before={c['name']for c in prior.get('checks',[])if c['passed']}if prior.get('rom_sha256')==meta['output_sha256']else set()
 file_crc=f'File CRC32: 0x{zlib.crc32(data):08X}'
 patch=(ROOT/'dist'/f'{NAME}.ips').read_bytes();out=bytearray(old);pos=5;assert patch[:5]==b'PATCH'
 while patch[pos:pos+3]!=b'EOF':
  a=int.from_bytes(patch[pos:pos+3],'big');n=int.from_bytes(patch[pos+3:pos+5],'big');pos+=5
  assert n>0
  if len(out)<a+n:out.extend(bytes(a+n-len(out)))
  out[a:a+n]=patch[pos:pos+n];pos+=n
 assert bytes(out)==data
 checks.append({'name':'exact original hash, output manifest hash and IPS reconstruction','passed':True})
 native=old[16:32784];patched=data[16:32784]
 word=lambda a:int.from_bytes(native[a-32768:a-32766],'little')
 for i in range(6):
  for table,n in [(0x8e10,576),(0x8b69,72)]:
   a=word(table+i*2)-32768;assert native[a:a+n]==patched[a:a+n]
 assert native[0x40cc:0x4212]==patched[0x40cc:0x4212] # timing-critical HUD timer/audio area
 assert native[0x20cc:0x2212]==patched[0x20cc:0x2212] # streamed original wrestler CHR upload
 checks.append({'name':'all six original portraits/stats, native timer and original wrestler CHR streaming retained','passed':True})
 ref=subprocess.run([sys.executable,str(BASE/'tools/port_probe.py'),'wwf',str(ROOT/'tests/reference_graphics.lua'),'--rom','C:/nes/WWF WrestleMania (USA).nes','--timeout','30'],capture_output=True,text=True,timeout=40)
 assert ref.returncode==0 and 'PASS 'in ref.stdout and 'FAIL 'not in ref.stdout,ref.stdout+ref.stderr
 checks.append({'name':'canonical HUD and ring graphics captured from the exact original ROM boot','passed':True})
 jobs=[('controller-game','game.lua',[]),('luigi-controller-game','game.lua',['CHOICES={1,0}']),('two-player-hardware','hardware.lua',['MODE=2']),('cpu-mixed-hardware','hardware.lua',[]),('six-player-tournament-menu','menu.lua',['MODE=7']),('win-transition','transition.lua',[]),('loss-transition','transition.lua',['WIN=false'])]
 jobs +=[('trailer-rope-graphics','rope_graphics.lua',[]),('luigi-trailer-rope-graphics','rope_graphics.lua',['CHOICES={1,0}'])]
 jobs +=[('directional-source-hardware','directional.lua',[])]
 jobs +=[('movement-pose-continuity','pose_continuity.lua',[])]
 jobs +=[(f'ring-reentry-{actor}-{brother}','ring_reentry.lua',[f'ACTOR={actor}',f'HUMAN={brother}'])for actor in range(2)for brother in range(2)]
 jobs +=[(f'rope-pin-recovery-{actor}-{brother}','rope_pin_recovery.lua',[f'ACTOR={actor}',f'HUMAN={brother}'])for actor in range(2)for brother in range(2)]
 jobs +=[('selection-raster-and-original-roster','menu_raster.lua',[]),('two-player-selection-raster','menu_raster.lua',['MODE=2'])]
 jobs +=[(f'defender-energy-bars-case-{i}','damage_owner.lua',[f'CASE={i}'])for i in range(1,5)]
 jobs +=[(f'original-opponent-{i}','opponent.lua',[f'OPPONENT={i}',f'HUMAN={i%2}'])for i in range(6)]
 jobs +=[(f'controller-full-match-original-{i}','pin_match.lua',[f'OPPONENT={i}',f'HUMAN={i%2}'])for i in range(6)]
 jobs +=[(f'controller-full-match-{actor}-{brother}','pin_match.lua',['TWO_PLAYER=true',f'ACTOR={actor}',f'HUMAN={brother}'])for actor,brother in [(1,0),(1,1),(0,0),(0,1)]]
 jobs +=[(f'combat-raster-original-{i}','combat_raster.lua',[f'OPPONENT={i}',f'HUMAN={i%2}'])for i in range(6)]
 jobs +=[(f'portrait-full-slide-{h}','portrait_slide.lua',[f'HUMAN={h}'])for h in range(2)]
 jobs +=[('two-player-portrait-slides','portrait_slide.lua',['MODE=2']),('six-player-portrait-slides','portrait_slide.lua',['MODE=7'])]
 jobs +=[(f'held-pin-at-rope-{a}-{edge}','pin_match.lua',['TWO_PLAYER=true',f'ACTOR={a}',f'EDGE={edge}',f'HUMAN={a}'])for a in range(2)for edge in [1,2]]
 jobs +=[(f'injury-anchor-{h}','hurt_pose.lua',[f'HUMAN={h}'])for h in range(2)]
 jobs +=[(f'full-post-victory-flow-{m}','after_victory.lua',[f'MATCH_MODE={m}'])for m in [0,1]]
 # An unfrozen opponent can legally kick out repeatedly. Allow a longer
 # bounded controller match while retaining every defeat/pin/winner check.
 jobs +=[('unfrozen-bam-bam-full-match','pin_match.lua',['OPPONENT=1','FREE_AI=true','MATCH_FRAMES=4400'])]
 logs=ROOT/'build/verification-logs';logs.mkdir(exist_ok=True)
 def job(item):
  name,script,defs=item
  path=logs/(name+'.txt')
  dependencies=[rom,ROOT/'build/manifest.json',BASE/'tools/port_probe.py',ROOT/'tests'/script,ROOT/'tests/common.lua',ROOT/'tests/graphics_oracle.lua']
  if name in passed_before and path.exists():
   log=path.read_text()
   if file_crc in log and all(p.stat().st_mtime_ns<=path.stat().st_mtime_ns for p in dependencies):
    return{'name':name,'passed':True,'log':str(path),'reused_same_rom':True}
  # Standard intentionally traverses the full intro/title/selection flow.
  # Keep its emulated-frame bound, while allowing a loaded host more wall time.
  timeout=90 if script=='after_victory.lua' else 55
  cmd=[sys.executable,str(BASE/'tools/port_probe.py'),'wwf',str(ROOT/'tests'/script),'--rom',str(rom),'--timeout',str(timeout)]
  for d in defs:cmd+=['--define',d]
  r=subprocess.run(cmd,capture_output=True,text=True,timeout=timeout+15);log=r.stdout+r.stderr;(logs/(name+'.txt')).write_text(log)
  passed=r.returncode==0 and 'PASS 'in log and 'FAIL 'not in log
  return {'name':name,'passed':passed,'log':str(logs/(name+'.txt'))}
 # Native emulator instances are isolated. Limit concurrency to two to
 # leave enough headroom for the expensive PPU/graphics timing audit.
 with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:
  for c in pool.map(job,jobs):checks.append(c);print(('PASS 'if c['passed']else'FAIL ')+c['name'],flush=True)
 receipt={'rom_sha256':meta['output_sha256'],'passed':all(c['passed']for c in checks),'checks':checks,'elapsed_seconds':round(time.time()-started,2),'limits':'Mesen controller replays include full-energy fireball defeats and real Down+A pins through victory for both controllers and all six original opponents. Most CPU pin replays suppress AI input without seeding health/positions/defeat/referee flags; an additional complete Bam Bam match and separate combat replays retain unfrozen AI. Rope-pin cases use position-only fixtures after a real controller defeat. New rope-pin recovery cases also select the RNG result for a legal native Up kick-out, then require actual inward walking and subsequent native melee damage. Ring reentry fixtures seed only coordinates and preserve native controls/actions. These replays compare complete HUD/portrait CHR against their clean match setup. Injury fixtures position the actors before real controller attacks. Post-victory Standard/Tournament scene tests use a referee fixture and continue into a second playable match. Static HUD/ring/deformable rope CHR through $1C2F is compared against a fresh original-ROM boot, excluding native generated name glyphs and the reserved split marker. Every match replay also checks complete human body and fireball patterns after the native split. The trailer rope replays compare all deformable rope patterns every frame and require visible bent-rope tiles for both brothers. Assembled 6502 tests are also included. Not an unassisted tournament clear or physical-console test.'}
 (ROOT/'dist/verification.json').write_text(json.dumps(receipt,indent=2))
 print(json.dumps({'passed':receipt['passed'],'checks':len(checks),'cpu_cases':sum(c.get('cases',0)for c in checks),'elapsed':receipt['elapsed_seconds']}))
 if not receipt['passed']:raise SystemExit(1)
if __name__=='__main__':main()
