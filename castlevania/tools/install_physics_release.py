"""Install this physics release with explicit, hash-bound validation scope.

The earlier Dracula release installer requires its exact full-game replay.
This release changes frame timing and collision, so its proof is the current
movement matrix, native integration, fresh first-door routes and raster tests.
No earlier full-game proof is attributed to this candidate.
"""
from datetime import datetime,timezone
from pathlib import Path
import hashlib,json,shutil,zipfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'analysis/physics-fix-2026-10-23'
TARGET=Path('C:/nes')
PREVIOUS='a0f346441b7fd5f73006b3c7491042667645b83949f16e18b4aee6653bd5abd4'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def report(p):return json.loads((ROOT/p).read_text())
def main():
    candidate=ROOT/'build/Mario in Castlevania.nes';digest=sha(candidate)
    suite=report('analysis/verification-results.json')
    assert suite['candidate_sha256']==digest
    assert all(suite[k] for k in ('motion_passed','physics_passed','tiles_passed','graphics_passed','artifact_passed'))
    from verify import SCRIPTS,verify_artifact
    assert {x['name'] for x in suite['tests']}==set(SCRIPTS)
    assert all(x['passed'] for x in suite['tests'])
    verify_artifact(candidate.read_bytes())
    physics=report('analysis/physics-results.json');assert physics['candidate_sha256']==digest and physics['passed'] and physics['cases']==160
    updates=physics['updates'];cases=physics['cases']
    for suffix in ('','/edges'):
        audit=report('analysis/physics-fix-2026-10-23/collision'+suffix+'/results.json')
        assert digest in audit['rom_hashes'].values() and audit['mismatching_cases']==0
        updates+=audit['compared_updates'];cases+=audit['cases']
    assert (cases,updates)==(360,19805)
    for p in ('analysis/physics-fix-2026-10-23/integration/results.json',
              'analysis/physics-fix-2026-10-23/raster/results.json',
              'analysis/native-graphics-results.json'):
        r=report(p);assert r['candidate_sha256']==digest and r['passed']
    raster=report('analysis/physics-fix-2026-10-23/raster/results.json')
    assert len(raster['cases'])==8 and raster['reference_sha256']==PREVIOUS
    performance=report('analysis/physics-fix-2026-10-23/final-workload.json')
    baseline=report('analysis/physics-fix-2026-10-23/original-workload.json')
    assert performance['candidate_sha256']==digest and baseline['candidate_sha256']==PREVIOUS
    assert performance['cases']==baseline['cases'] and performance['case_state_sha256']==baseline['case_state_sha256']
    for stage in ('10','12','14'):
        assert performance['stages'][stage]['updates']>=500
        assert performance['stages'][stage]['missed_percent']<1
    first=report('analysis/performance-budget.json');assert first['passed'] and first['maximum_percent']==1
    for name,expected in {
        'Castlevania (USA) (Rev 1).nes':'5e859d77bc0e3a9f30a7c14d2637b9c2aae6ce19f6520a7c9b252a86974f7800',
        'Super Mario Bros. (World).nes':'0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea',
    }.items():assert sha(TARGET/name)==expected
    previous=sha(TARGET/candidate.name)
    assert previous in (PREVIOUS,digest),'Preserve an unrecognized newer installed build'
    backup=ROOT/'build/previous-installed'/PREVIOUS[:12]
    backup.mkdir(parents=True,exist_ok=True)
    names=['Mario in Castlevania.nes','Mario in Castlevania.ips','Mario in Castlevania - Controls.txt']
    for name in names:
        current=TARGET/name
        if previous==PREVIOUS and current.exists():
            if not (backup/name).exists():shutil.copyfile(current,backup/name)
            assert sha(current)==sha(backup/name)
    assert sha(backup/candidate.name)==PREVIOUS
    for name in names:
        source=ROOT/'build'/name;temporary=TARGET/(name+'.physics-update.tmp')
        shutil.copyfile(source,temporary);assert sha(temporary)==sha(source)
        temporary.replace(TARGET/name);assert sha(TARGET/name)==sha(source)
    release={'installed_at':datetime.now(timezone.utc).isoformat(),
             'installed_rom':str(TARGET/candidate.name),'installed_sha256':digest,
             'previous_sha256':PREVIOUS,'backup_directory':str(backup),
             'emulator_regressions':len(suite['tests']),'SMB_movement_cases':cases,'SMB_movement_updates':updates,
             'matched_fireball_launches_and_stomp_fractions':True,'raster_pixel_cases':8,
             'native_graphics_commands':11,'native_metasprites':239,
             'performance':performance['stages'],'performance_baseline':baseline['stages'],
             'first_room_performance':first,'full_game_clear_verified_for_this_build':False,
             'changes':['SMB post-movement feet and side collision, retained direction masks and one-pixel wall ejection',
                        'Consistent local/world coordinates after wall ejection at the scroll center',
                        'Stomps preserve vertical velocity and position fractions without snapping Mario',
                        'Moving platforms detach before horizontal movement on the first jump update',
                        'Fireballs use SMB launch coordinates and crouching prevents throws',
                        'SMB standing/small/crouched combat bounds and walking-off animation',
                        'MMC5 raster interrupt replaces the native HUD polling wait',
                        'Renderer stops at the 47 available gameplay OAM entries without overwriting earlier sprites'],
             'limitations':['Castlevania stairs, doors, health, knockback, whip, subweapons, 8-pixel terrain and native pit death remain deliberate adaptations',
                            '360 comparison cases cover ordinary movement; 51 post-pit-death samples are retained separately',
                            'Fresh controller regression routes reach the first indoor door; late rooms/bosses and credits also have directed native fixtures',
                            'The earlier full-game video and replay belong to the previous ROM; this new build has no new continuous full-game clear proof',
                            'Rare native missed updates remain in the directed workloads; slowdown is substantially reduced, not guaranteed absent in every situation'],
             'reload':'Close/reload the ROM and start a new game; do not restore a previous-build savestate'}
    (ROOT/'analysis/release-physics-2026-10-23.json').write_text(json.dumps(release,indent=2))
    notes=(f'Mario in Castlevania physics fixes - 2026-10-23\n\n'
           f'ROM SHA256: {digest}\nPrevious release backed up to: {backup}\n\n'
           f'Validated: {len(suite["tests"])} emulator regressions; {cases} original-SMB movement cases / {updates:,} ordinary updates; '
           'stomp fractions, fireball launches, platform takeoff, 24 bounds/animation cases, '
           'all 239 native metasprites across 11 graphics commands, and eight pixel-identical HUD/background frames.\n\n'
           'Busy-room missed-update rates in matched directed checkpoint workloads:\n'+
           '\n'.join(f'Stage {s}: {baseline["stages"][s]["missed_percent"]:.3f}% -> {performance["stages"][s]["missed_percent"]:.3f}%' for s in ('10','12','14'))+
           '\n\nThese are directed benchmarks, not full-level playthroughs. The new build has no fresh continuous full-game clear proof. '
           'The previous full-game video/replay still describe the previous ROM.\n\n'
           'Reload the ROM and start a new game. Old savestates contain the old code addresses, mapper state and physics state.\n')
    (ROOT/'build/Mario in Castlevania - Physics fixes.txt').write_text(notes)
    shutil.copyfile(ROOT/'build/Mario in Castlevania - Physics fixes.txt',TARGET/'Mario in Castlevania - Physics fixes.txt')
    with zipfile.ZipFile(ROOT/'build/source-verified-physics-2026-10-23.zip','w',zipfile.ZIP_DEFLATED) as z:
        for folder in ('src','tools','tests','reference'):
            for p in sorted((ROOT/folder).rglob('*')):
                if p.is_file() and '__pycache__' not in p.parts and p.suffix.lower() not in ('.nes','.sav','.state'):
                    z.write(p,p.relative_to(ROOT))
        for folder in ('analysis/verification','analysis/physics-fix-2026-10-23'):
            for p in sorted((ROOT/folder).rglob('*')):
                if p.is_file() and p.suffix.lower() in ('.json','.csv','.lua','.log','.png'):
                    z.write(p,p.relative_to(ROOT))
        for name in ('verification-results.json','physics-results.json','physics-smb.csv','physics-hybrid.csv',
                     'physics-reference-capture.json','native-graphics-results.json','motion-results.json','tile-results.json',
                     'performance-budget.json','release-physics-2026-10-23.json'):
            z.write(ROOT/'analysis'/name,'analysis/'+name)
        for name in ('patch-manifest.json','mario.lst','hack.map','hack.lbl','Mario in Castlevania.ips',
                     'Mario in Castlevania - Controls.txt','Mario in Castlevania - Physics fixes.txt'):
            z.write(ROOT/'build'/name,'build/'+name)
    print('Installed verified physics release:',digest)
    print('Original release retained:',backup)
    print('Regression checks:',len(suite['tests']),'SMB cases:',cases,'compared movement updates:',updates)
if __name__=='__main__':main()
