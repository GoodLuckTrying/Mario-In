"""Install the exact verified candidate, retaining the previous release."""
from datetime import datetime, timezone
import hashlib
import json
import re
from pathlib import Path
import shutil
import zipfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE_DIR=Path('C:/nes')
TARGET=SOURCE_DIR/'Mario In'
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

report=json.loads((ROOT/'analysis/verification-results.json').read_text())
candidate=ROOT/'build/Mario in Castlevania.nes'
sha=digest(candidate)
assert report['candidate_sha256']==sha
assert all(report[key] for key in ('motion_passed','physics_passed','tiles_passed','graphics_passed','artifact_passed'))
assert all(test['passed'] for test in report['tests'])
assert any(test['name']=='dracula-head' and test['passed'] for test in report['tests'])
fullgame=json.loads((ROOT/'analysis/fullgame-results.json').read_text())
assert fullgame['candidate_sha256']==sha and fullgame['full_game_clear'] and fullgame['fresh_boot_verified']
dracula=json.loads((ROOT/'analysis/dracula-head-results.json').read_text())
assert dracula['candidate_sha256']==sha and dracula['passed']
assert any(test['name']=='scroll-background' and test['passed'] for test in report['tests'])
background_log=(ROOT/'analysis/verification/scroll-background.log').read_text()
counts=re.search(r'Original backgrounds: (\d+) tile/attribute checks; (\d+) candle spawns, (\d+) visible candle checks and (\d+) enemy-spawner placement checks',background_log)
assert counts, 'Background and object placement evidence must accompany this release'
background={
    'candidate_sha256':sha,'passed':True,
    'tile_and_attribute_checks':int(counts[1]),'candle_spawns':int(counts[2]),
    'visible_candle_checks':int(counts[3]),'enemy_spawner_placement_checks':int(counts[4]),
    'rooms':[{'stage':3,'room':0,'boss_lock':True},{'stage':4,'room':1},{'stage':5,'room':0}],
    'evidence_type':'Native room initialization and controller movement on directed flat collision support; original background data and object records unchanged',
    'log':'analysis/verification/scroll-background.log',
}
(ROOT/'analysis/boss-background-results.json').write_text(json.dumps(background,indent=2))
assert all(any(test['name']==name and test['passed'] for test in report['tests'])
           for name in ('sprite-lifecycle','sprite-inactive'))
sprite_log=(ROOT/'analysis/verification/sprite-lifecycle.log').read_text()
sprite_counts=re.search(r'Sprite lifecycle passed: (\d+) renders, (\d+) unused OAM checks, (\d+) empty spawns, (\d+) active candle shifts; right/left scrolls (\d+)/(\d+)',sprite_log)
assert sprite_counts, 'Controller sprite lifecycle evidence must accompany this release'
sprite_size_counts=re.search(r'Sprite size coverage: (\d+) small renders, (\d+) grown renders',sprite_log)
assert sprite_size_counts, 'Both Mario sizes must accompany controller sprite evidence'
sprites={
    'candidate_sha256':sha,'passed':True,
    'renders':int(sprite_counts[1]),'unused_oam_checks':int(sprite_counts[2]),
    'small_renders':int(sprite_size_counts[1]),'grown_renders':int(sprite_size_counts[2]),
    'empty_spawns':int(sprite_counts[3]),'active_candle_shifts':int(sprite_counts[4]),
    'right_scrolls':int(sprite_counts[5]),'left_scrolls':int(sprite_counts[6]),
    'evidence_type':'Fresh controller-only route covers small and grown Mario with forward scrolling and backtracking; separate retained inactive-pose fixture preserves Mario and native auxiliary graphics',
    'log':'analysis/verification/sprite-lifecycle.log',
    'inactive_pose_log':'analysis/verification/sprite-inactive.log',
    'previous_release_sha256':'a19a74e4cd9b1f21731f1300bca96231ee058c3ec8957316dc4c88f434e76bc8',
    'previous_release_reproductions':['analysis/sprite-lifecycle-previous-release.log','analysis/sprite-inactive-previous-release.log'],
}
(ROOT/'analysis/sprite-lifecycle-results.json').write_text(json.dumps(sprites,indent=2))
assert any(test['name']=='moving-platforms' and test['passed'] for test in report['tests'])
platform_log=(ROOT/'analysis/verification/moving-platforms.log').read_text()
platform_counts=re.search(r'Moving platforms passed: (\d+) native stage/size cases; (\d+) grounded ride checks, (\d+) jumps, (\d+) landings, (\d+) walk-offs; left/right carry (\d+)/(\d+)',platform_log)
assert platform_counts, 'Native platform movement evidence must accompany this release'
platforms={
    'candidate_sha256':sha,'passed':True,
    'stage_size_cases':int(platform_counts[1]),'grounded_ride_checks':int(platform_counts[2]),
    'jumps':int(platform_counts[3]),'landings':int(platform_counts[4]),'walk_offs':int(platform_counts[5]),
    'left_carry_steps':int(platform_counts[6]),'right_carry_steps':int(platform_counts[7]),
    'native_stages':[4,5,10],'mario_sizes':[0,1,2],
    'evidence_type':'Original native platform records and oscillation routines in initialized rooms; controlled player placement and terrain isolation with real controller edges for steering and jumping',
    'log':'analysis/verification/moving-platforms.log',
    'previous_release_sha256':'d58838efde426f3ee2cb474174578625dfadbf9f77c981b18bddbc77768da046',
    'previous_release_reproduction':'analysis/moving-platforms-previous-release.log',
}
(ROOT/'analysis/moving-platform-results.json').write_text(json.dumps(platforms,indent=2))
assert all(any(test['name']==name and test['passed'] for test in report['tests'])
           for name in ('combat-animation','damage-low-health','subweapon-multiplier'))
combat_log=(ROOT/'analysis/verification/combat-animation.log').read_text()
health_log=(ROOT/'analysis/verification/damage-low-health.log').read_text()
multiplier_log=(ROOT/'analysis/verification/subweapon-multiplier.log').read_text()
combat_counts=re.search(r'Combat animation passed: (\d+) cases',combat_log)
health_counts=re.search(r'Low-health damage passed: (\d+) cases; threshold 16/64 HP',health_log)
multiplier_counts=re.search(r'Subweapon multipliers passed: (\d+) pickups/throws and (\d+) capacity checks',multiplier_log)
assert combat_counts and health_counts and multiplier_counts
combat={
    'candidate_sha256':sha,'passed':True,
    'animation_and_friendly_actor_cases':int(combat_counts[1]),
    'health_threshold_cases':int(health_counts[1]),'shrink_threshold_hp':16,'maximum_hp':64,
    'native_multiplier_pickup_and_throw_cases':int(multiplier_counts[1]),
    'native_projectile_capacity_cases':int(multiplier_counts[2]),
    'evidence_type':'Controlled native damage/collision handlers, native II/III pickup contact and real Up+B edges; not later-stage controller clears',
    'previous_release_sha256':'d614b5c4ac12e87fb6d408dfbec317cc18db7451f8ada5d548e7b2bbe2698fde',
    'previous_release_reproductions':['analysis/combat-animation-previous-release.log','analysis/friendly-weapons-previous-release.log'],
}
(ROOT/'analysis/combat-crouch-results.json').write_text(json.dumps(combat,indent=2))
assert all(any(test['name']==name and test['passed'] for test in report['tests'])
           for name in ('native-ai-banks','stair-transitions'))
ai_log=(ROOT/'analysis/verification/native-ai-banks.log').read_text()
stair_log=(ROOT/'analysis/verification/stair-transitions.log').read_text()
ai_counts=re.search(r'Native AI banks passed: (\d+) live enemy cases; (\d+) actor dispatches, (\d+) Mario returns, (\d+) contacts, (\d+) splashes, (\d+) shots, (\d+) platform updates',ai_log)
stair_counts=re.search(r'Stair transitions passed: (\d+) native round trips; (\d+) palette checks, (\d+) room changes',stair_log)
assert ai_counts and stair_counts, 'Native AI and stair evidence must accompany this release'
native_ai_stairs={
    'candidate_sha256':sha,'passed':True,
    'live_enemy_cases':int(ai_counts[1]),'actor_dispatches':int(ai_counts[2]),
    'bank_safe_mario_returns':int(ai_counts[3]),'contact_paths':int(ai_counts[4]),
    'native_splash_paths':int(ai_counts[5]),'native_shot_paths':int(ai_counts[6]),
    'native_platform_updates':int(ai_counts[7]),
    'native_stair_round_trips':int(stair_counts[1]),'mario_palette_checks':int(stair_counts[2]),
    'stair_room_changes':int(stair_counts[3]),
    'evidence_type':'Native room initialization with controlled actor/player placements; actual fish-man AI, mixed actor dispatch, moving platforms and Up/Down stair input; all non-Mario native palette bytes preserved',
    'previous_release_sha256':'27c3e82f327d02fd4474827a78bc6d176911f0f6aad96d24450dc80baba0b1d2',
    'previous_release_reproductions':['analysis/native-ai-banks-previous-release.log','analysis/bank-return-previous-release.log','analysis/stair-palette-previous-release.log'],
    'logs':['analysis/verification/native-ai-banks.log','analysis/verification/stair-transitions.log'],
    'limitations':['These are directed native integration fixtures, not complete stage clears'],
}
(ROOT/'analysis/native-ai-stairs-results.json').write_text(json.dumps(native_ai_stairs,indent=2))
for name,expected in {
    'Castlevania (USA) (Rev 1).nes':'5e859d77bc0e3a9f30a7c14d2637b9c2aae6ce19f6520a7c9b252a86974f7800',
    'Super Mario Bros. (World).nes':'0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea',
}.items():
    assert digest(SOURCE_DIR/name)==expected, 'Original source ROM must remain unchanged'
graphics=json.loads((ROOT/'analysis/native-graphics-results.json').read_text())
assert graphics['candidate_sha256']==sha and graphics['passed']
physics=json.loads((ROOT/'analysis/physics-results.json').read_text())
assert physics['candidate_sha256']==sha and physics['passed']
assert physics['cases']==160 and physics['updates']==12800 and 'crouch' in physics['fields']
TARGET.mkdir(parents=True,exist_ok=True)
previous=digest(TARGET/candidate.name)
backup=ROOT/'build/previous-installed'/previous[:12]
backup.mkdir(parents=True,exist_ok=True)
names=['Mario in Castlevania.nes','Mario in Castlevania.ips','Mario in Castlevania - Controls.txt']
for name in names:
    current=TARGET/name
    if current.exists():
        if not (backup/name).exists(): shutil.copyfile(current,backup/name)
        assert digest(current)==digest(backup/name), 'Backup must match installed file'
for name in names:
    source=ROOT/'build'/name
    temporary=TARGET/(name+'.verified-update.tmp')
    shutil.copyfile(source,temporary)
    assert digest(temporary)==digest(source)
    temporary.replace(TARGET/name)
    assert digest(TARGET/name)==digest(source)
release={
    'installed_at':datetime.now(timezone.utc).isoformat(),
    'installed_rom':str(TARGET/candidate.name),'installed_sha256':sha,
    'previous_sha256':previous,'backup_directory':str(backup),
    'emulator_checks':len(report['tests']),
    'physics_evidence':'analysis/physics-results.json',
    'physics_cases':physics['cases'],'physics_updates':physics['updates'],
    'graphics_evidence':'analysis/native-graphics-results.json',
    'graphics_commands':graphics['graphics_commands'],'native_poses':graphics['native_poses'],
    'background_evidence':background,
    'sprite_evidence':sprites,
    'platform_evidence':platforms,
    'combat_evidence':combat,
    'native_ai_and_stair_evidence':native_ai_stairs,
    'crouch_evidence':'24 additional original SMB duck-slide, crouch-jump and crouch-release cases, both directions, both grown sizes and two starting speeds',
    'dracula_head_evidence':dracula,
    'fullgame_evidence':fullgame,
    'changes':[
        'Native fish-man splash/shoot routines can return in bank 6; fixed trampolines restore bank 5 before Mario pickups, damage and each banked actor dispatch',
        'Native scripted gate, door and stair AI paths use the same bank-safe return bridge',
        'Native sprite palette commands preserve Mario form through stairs and room reloads while retaining every non-Mario palette byte',
        'Simultaneous Left+Right preserves original SMB input behavior instead of forcing Right through the Simon controller filter',
        '60 added exact original-SMB movement cases cover acceleration from rest, run release, neutral braking, combined directions, jump release/repress and crouch ceilings at all sizes',
        'Original graphics, moving-platform support, camera limits, native health damage, food, whip and subweapons remain verified',
        'Dracula hidden-head cooldown expires through its native body AI in both forms, allowing repeated Mario whip and fireball hits',
        'A continuous fresh-power-on controller replay defeats all bosses and reaches native ending credits; live holy water bottle and flame damage are recorded against Dracula',
    ],
    'healing':'Native food +24 HP capped at 64; money bags award points; orbs retain full healing and stage completion',
    'performance':json.loads((ROOT/'analysis/performance-budget.json').read_text()),
    'emulator_requirement':'NES 2.0 MMC5 (mapper 5), 16KB CHR RAM; reload the ROM and start a new game',
    'limitations':['II/III holy water pickup and capacity checks use controlled native fixtures; the live boss fight uses single holy water',
                   'The verified continuous full-game controller route includes four ordinary deaths'],
}
(ROOT/'analysis/release-dracula-head.json').write_text(json.dumps(release,indent=2))
with zipfile.ZipFile(ROOT/'build/source-verified-dracula-head.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for directory in ('src','tools','tests','reference/smb'):
        for path in sorted((ROOT/directory).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                archive.write(path,path.relative_to(ROOT))
    for name in ('verification-results.json','native-graphics-results.json','release-dracula-head.json',
                 'fullgame-results.json','holy-water-results.json','dracula-head-results.json','dracula-head-previous-release.log','verification/dracula-head.log','verification/holy-water-damage.log',
                 'motion-results.json','physics-results.json','tile-results.json','performance-budget.json','boss-background-results.json',
                 'sprite-lifecycle-results.json','sprite-lifecycle-previous-release.log','sprite-inactive-previous-release.log',
                 'moving-platform-results.json','moving-platforms-previous-release.log',
                 'combat-crouch-results.json','combat-animation-previous-release.log','friendly-weapons-previous-release.log',
                 'native-ai-stairs-results.json','native-ai-banks-previous-release.log','bank-return-previous-release.log','stair-palette-previous-release.log',
                 'verification/native-ai-banks.log','verification/stair-transitions.log','verification/physics-comparison.log',
                 'physics-reference-capture.json','verification-reruns.json',
                 'physics-candidate-prefix.json','physics-hybrid-prefix.csv','physics-smb.csv','physics-hybrid.csv'):
        archive.write(ROOT/'analysis'/name,'analysis/'+name)
    for name in ('stage18-credits-route.json','stage18-credits-composed-input.csv','stage18-credits-fresh.log','stage18-credits-fresh-trace.csv','stage18-credits-fresh.png','dracula-second-live-water-hits.csv'):
        archive.write(ROOT/'analysis/fullgame'/name,'analysis/fullgame/'+name)
    for segment in json.loads((ROOT/'analysis/fullgame/stage18-credits-route.json').read_text())['segments']:
        for suffix in ('.json','.config.json','-input.csv'):
            path=ROOT/'analysis/fullgame'/(segment+suffix)
            if path.exists(): archive.write(path,path.relative_to(ROOT))
print(f'Installed verified ROM: {sha}; {len(report["tests"])} emulator checks passed.')
print(f'Previous ROM, patch and controls backed up to {backup}')
