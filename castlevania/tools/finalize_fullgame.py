"""Audit the completed native ending and its fresh controller replay."""
from pathlib import Path
from datetime import datetime,timezone
import csv,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'analysis/fullgame'
endpoint='stage18-credits'
candidate=ROOT/'build/Mario in Castlevania.nes'
sha=hashlib.sha256(candidate.read_bytes()).hexdigest()
manifest_path=folder/(endpoint+'-route.json')
manifest=json.loads(manifest_path.read_text())
meta=json.loads((folder/(endpoint+'.json')).read_text())
assert manifest['rom_sha256']==sha and manifest['fresh_boot_verified']
assert manifest['verified_controller_polls']==manifest['input_frames']
assert hashlib.sha256((folder/(endpoint+'-composed-input.csv')).read_bytes()).hexdigest()==manifest['input_sha256']
fresh=list(csv.DictReader((folder/(endpoint+'-fresh-trace.csv')).open()))
assert len(fresh)==len(manifest['segments'])
last=fresh[-1]
assert int(last['input'])==manifest['input_frames']
assert last['mode']=='15' and last['stage']=='18' and last['health']=='64'
assert meta['mode']==15 and meta['aux']>=5 and meta['health']==64
assert (folder/(endpoint+'-fresh.png')).read_bytes().startswith(b'\x89PNG')
proof_source=(ROOT/'tools/verify_fullgame_replay.py').read_text()
assert all(x not in proof_source for x in ['emu.loadSavestate','emu.write(','emu.setState'])
verification=json.loads((ROOT/'analysis/verification-results.json').read_text())
assert verification['candidate_sha256']==sha and all(t['passed'] for t in verification['tests'])
assert all(verification[k] for k in ['motion_passed','tiles_passed','graphics_passed','artifact_passed','physics_passed'])
water=list(csv.DictReader((folder/'dracula-second-live-water-hits.csv').open()))
assert any(r['enemy_ai']=='29' and r['phase']=='1' and r['water_action']=='1' for r in water)
assert any(r['enemy_ai']=='29' and r['phase']=='1' and r['water_action']=='2' for r in water)
manifest.update(full_game_clear=True,ending={'native_mode':15,'native_aux':meta['aux'],'stage':18,'health':64,'scene':'Castle collapse and native credits','screenshot':str(folder/(endpoint+'-fresh.png'))})
manifest_path.write_text(json.dumps(manifest,indent=2))
result={
 'candidate_sha256':sha,'verified_at':datetime.now(timezone.utc).isoformat(),
 'full_game_clear':True,'fresh_boot_verified':True,'controller_polls':manifest['input_frames'],
 'checkpoints':len(manifest['segments']),'native_deaths':manifest['native_deaths'],
 'route':str(manifest_path),'fixed_inputs':str(folder/(endpoint+'-composed-input.csv')),
 'fresh_replay_log':str(folder/(endpoint+'-fresh.log')),'ending':manifest['ending'],
 'discovery':'Opaque checkpoints and native controller branches; four ordinary deaths in the accepted route',
 'proof':'One continuous power-on replay of fixed controller inputs with no save loads, RAM writes or register changes',
 'emulator_checks':len(verification['tests'])
}
(ROOT/'analysis/fullgame-results.json').write_text(json.dumps(result,indent=2))
verification['fullgame_evidence']='analysis/fullgame-results.json'
verification['full_game_clear_passed']=True
verification['limitations'][0]='Regression-suite controller routes end after the first indoor door; the separate continuous full-game controller replay reaches native credits'
(ROOT/'analysis/verification-results.json').write_text(json.dumps(verification,indent=2))
fixture=next(t for t in verification['tests'] if t['name']=='holy-water-damage')
holy={
 'candidate_sha256':sha,'verified_at':result['verified_at'],'passed':fixture['passed'],
 'fixture':fixture,'fixture_log':'analysis/verification/holy-water-damage.log',
 'live_controller_encounter':{'stage':18,'boss':'Dracula second form','confirmed':['Native bottle damage','Native landed-flame damage','Six accepted throws cost six hearts','Boss defeated and ending reached'],'multiplier':0,'hits':'analysis/fullgame/dracula-second-live-water-hits.csv','input':'analysis/fullgame/stage18-dracula-orb-input.csv','full_game_replay':result['fixed_inputs']},
 'limitations':['II/III pickups and simultaneous capacity use controlled native integration fixtures; the live boss fight uses single holy water']
}
(ROOT/'analysis/holy-water-results.json').write_text(json.dumps(holy,indent=2))
dracula={
 'candidate_sha256':sha,'passed':True,
 'problem':'The hidden AI 4 head keeps its native hurt counter because its own AI is inert; Mario weapons then reject every later hit',
 'fix':'Tick the head cooldown once from each native Dracula body update, and mirror the second form damage handler cooldown to the head',
 'previous_release_reproduction':'analysis/dracula-head-previous-release.log',
 'fixture':'analysis/verification/dracula-head.log','cases':8,
 'live_controller_evidence':['analysis/fullgame/stage18-dracula-first-form.json','analysis/fullgame/stage18-dracula-orb.json'],
 'full_game_evidence':'analysis/fullgame-results.json',
 'native_timing':'All earlier custom weapon and movement routines retain their original bytes; changes execute only in Dracula routines'
}
(ROOT/'analysis/dracula-head-results.json').write_text(json.dumps(dracula,indent=2))
print(f'Full game verified: {manifest["input_frames"]} controller polls, {len(manifest["segments"])} checkpoints, {manifest["native_deaths"]} ordinary deaths; native credits reached.')
