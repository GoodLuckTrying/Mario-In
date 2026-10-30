"""Compare controlled hybrid motion fixtures with the user's original SMB ROM."""
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SMB = Path('C:/nes/Super Mario Bros. (World).nes')
ROM = ROOT/'build/Mario in Castlevania.nes'
FIELDS = ('xspeed', 'xforce', 'xabs', 'facing', 'moving', 'runflag', 'runtimer')
VERTICAL = ('vhi', 'vlo', 'yfrac', 'y', 'gravity', 'fallforce')
NAMES = ('stationary held jump', 'walk-speed held jump', 'running jump threshold',
         'full running jump', 'release and repress A', 'running and ground braking',
         'neutral air and midair B', 'walking, reversing and braking', 'walk to run')

def main():
    for script, rom in [('smb-motion', SMB), ('hybrid-motion', ROM),
                        ('smb-fireball', SMB), ('fireball-motion', ROM)]:
        subprocess.run([sys.executable, str(ROOT/'tools/run_mesen.py'),
                        str(ROOT/f'tests/{script}.lua'), str(rom)], cwd=ROOT, check=True)
    def read(name):
        with (ROOT/f'analysis/{name}-motion.csv').open() as f:
            return {(int(r['scenario']), int(r['tick'])): r for r in csv.DictReader(f)}
    original, hybrid = read('smb'), read('hybrid')
    assert original.keys() == hybrid.keys(), 'Missing frame traces'
    results = []
    for scenario, name in enumerate(NAMES, 1):
        last = 35 if scenario == 7 else 130 if scenario == 9 else 149
        fields = FIELDS + (VERTICAL if scenario <= 5 or scenario == 7 else ())
        for tick in range(1, last+1):
            key = scenario, tick
            assert key in original, f'Missing {key}'
            for field in fields:
                assert original[key][field] == hybrid[key][field], (
                    name, tick, field, original[key][field], hybrid[key][field])
        results.append({'scenario': name, 'compared_frames': last, 'fields': fields})
        print(f'{name}: {last} frames match SMB')
    def fireball(name):
        with (ROOT/f'analysis/{name}-fireball.csv').open() as f:
            return list(csv.DictReader(f))
    original_fireball, hybrid_fireball = fireball('smb'), fireball('hybrid')
    assert len(original_fireball) == len(hybrid_fireball) == 20
    assert original_fireball == hybrid_fireball, 'Fireball flight differs from SMB'
    print('Fireball flight: 20 frames match SMB')
    report = {'candidate_sha256': hashlib.sha256(ROM.read_bytes()).hexdigest(),
              'reference_sha256': hashlib.sha256(SMB.read_bytes()).hexdigest(),
              'evidence_type': 'Controlled RAM-seeded motion comparison; not a playthrough',
              'limitations': ['World X/camera handoff is checked by integration tests',
                              'Terrain, enemies and transitions are separate checks'],
              'scenarios': results,
              'fireball': {'compared_frames': 20, 'fields': list(original_fireball[0])}}
    (ROOT/'analysis/motion-results.json').write_text(json.dumps(report, indent=2))

if __name__ == '__main__':
    main()
