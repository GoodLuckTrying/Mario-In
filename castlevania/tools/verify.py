"""Verify one candidate ROM and retain evidence with its exact hash."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT/'build/Mario in Castlevania.nes'
SCRIPTS = {
    'sprite-budget': 'Directed native renderer saturation at underfull, exact-full and overflowing OAM capacity; unique allocations, HUD reservation, cleanup and bounded CPU cycles',
    'dracula-head': 'Controlled repeated native head hits, blocked cooldown hits, natural timer expiry and both Dracula forms',
    'heart-contact': 'Controlled pickup and HUD fixture',
    'coin-contact': 'Controlled pickup contact safety fixture',
    'regressions': 'Controlled lamp bump immunity, native lamp position, power cap, intro and stair rendering fixtures',
    'actor-reuse': 'Controlled native actor slot reuse fixtures',
    'sprite-lifecycle': 'Fresh controller-only route covers small and grown Mario, forward/backtracking scrolling, native empty spawn slots, active candle camera shifts and complete unused OAM cleanup',
    'sprite-inactive': 'Controlled retained stale actor pose with native auxiliary and Mario rendering preserved',
    'combat-animation': 'Controlled original enemy animation holds versus live damage timers; whip, fireball, stomp and native friendly projectile immunity',
    'damage-low-health': 'Controlled native hits at both sides of the 16/64 HP threshold, all Mario sizes, native damage and lethal clamp',
    'subweapon-multiplier': 'Native II/III pickup contact, real Up+B throws for all four projectile weapons, allowed last slot and full capacity with heart costs',
    'holy-water-damage': 'Controlled native II/III pickups and real Up+B throws through bottle landing, simultaneous projectile capacity, heart costs, flame damage and native enemy death',
    'native-ai-banks': 'Native fish-man spawn/shoot/splash, contact damage and mixed banked enemy dispatch in initialized stair and moving-platform rooms',
    'stair-transitions': 'Native Up/Down stair round trips at every Mario size, room seams and Mario palette checks',
    'moving-platforms': 'Natively initialized platform rooms in stages 4, 5 and 10 at all three sizes; controlled player placement and terrain isolation, real controller input for riding, steering, jumps, landings and walk-offs',
    'candle-persistence': 'Controlled candle persistence, whip and native axe integration',
    'all-subweapons': 'Controlled native subweapon integration',
    'fixtures': 'Controlled stomp, shrink and surviving small-Mario health damage',
    'stomp': 'Controlled stomp priority before and after native enemy movement',
    'native-damage': 'Isolated native boss, multipart damage, cooldown and pickup immunity fixtures',
    'terrain': 'Controlled small/grown wall probes and thin ceilings at all three sizes and standing/running speeds',
    'local-bounds': 'Controlled local screen boundary crossings',
    'scroll-crossing': 'Controlled camera center crossings in both directions',
    'scroll-background': 'Native initialized boss/vertical rooms, both scroll directions, original nametable tiles and palette attributes, authored candle and enemy-spawner positions on directed collision support',
    'scroll-limits': 'All native stage/room camera limits, subpixels, active boss locks and first-boss running activation',
    'top-and-pit': 'Controlled top coordinate safeguard and native pit death',
    'respawn': 'Controlled lethal contact followed by native death and respawn',
    'fireball-lifecycle': 'Controlled projectile capacity, input, lifetime, camera and bounce',
    'fireball-bricks': 'Controlled original wall records: both directions, floor, ordinary terrain, room, persistence and hidden drops',
    'whip-bricks': 'Controlled small/grown whip wall reach, direction, room, persistence, original hidden items and fireball independence',
    'whip-combat': 'Controlled whip reach, facing, size damage, candles, stairs, multiple targets and native boss cooldown',
    'whip-lifecycle': 'Actual B button edges with controlled size, whip graphics, simultaneous fireballs and Up+B separation',
    'whip-lower': 'Actual Down+B native crouch attacks at all three sizes and both facings, with low targets and matching graphics',
    'whip-route': 'Fresh-start controller-only small whip combat and original zombie death handler',
    'health-food': 'Controlled native stage damage, shrinking, small-Mario survival, invincibility, lethal clamp, food and health HUD',
    'food-art': 'Controlled native food rendering in both directions, original CHR pixels and healing at all Mario sizes',
    'native-items': 'Controlled original money bag/orb OAM and pixel rendering, points, health and native stage completion',
    'brick-route': 'Fresh-start controller-only power-ups and B attack brick destruction, including native background removal',
    'transition-weapons': 'Controlled subweapon, scripted door and whip cancellation integration',
    'full-door': 'Controlled full native door sequence integration',
    'real-door': 'Native gate and door route with forced power and invincibility',
    'scroll-run': 'Fresh-start controller-only exterior run and gate route',
    'candles': 'Fresh-start controller-only mushroom and flower collection',
    'floor-candle': 'Fresh-start controller-only first indoor floor lamp weapon hit and heart pickup',
    'playthrough': 'Fresh-start controller-only upgrades, heart, combat, stairs and first door',
    'performance': 'Read-only first-room/exterior missed-vblank budget on the fresh controller route',
}


def run(name):
    timeout = 50 if name=='scroll-limits' else 25
    result = subprocess.run([sys.executable, str(ROOT/'tools/run_mesen.py'),
                             str(ROOT/f'tests/{name}.lua'), str(ROM), f'--timeout={timeout}'],
                            cwd=ROOT, text=True, capture_output=True, timeout=timeout+20)
    (ROOT/f'analysis/verification/{name}.log').write_text(result.stdout+result.stderr)
    return {'name': name, 'evidence_type': SCRIPTS[name],
            'passed': result.returncode == 0, 'exit_code': result.returncode}


def verify_artifact(rom):
    smb = Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[16+32768:]
    source = Path('C:/nes/Castlevania (USA) (Rev 1).nes').read_bytes()
    flip = lambda tile: bytes(int(f'{v:08b}'[::-1], 2) for v in tile)
    custom = (ROOT/'build/custom-sprites.chr').read_bytes()
    for index, original in [(15, 0x4f), (50, 0x4a), (51, 0x4b)]:
        assert custom[index*16:(index+1)*16] == flip(smb[original*16:(original+1)*16]), 'Standing art must mirror'
    from native_graphics import metasprites, sprite_remap, chr_transfers
    mapping = sprite_remap(source)
    for command in range(11):
        for offset,_,length in chr_transfers(source,command):
            assert rom[offset:offset+length] == source[offset:offset+length], 'All native graphics transfer sources must remain intact'
    for original_pose, candidate_pose in zip(metasprites(source),metasprites(rom)):
        assert len(original_pose)==len(candidate_pose)
        for original,candidate in zip(original_pose,candidate_pose):
            assert candidate['tile']==mapping.get(original['tile'],original['tile']), 'Every native metasprite must reference its original pixels'
            for field in ('y','x','attribute'):
                assert original[field]==candidate[field], 'Native sprite layout and palette must remain intact'
    labels = json.loads((ROOT/'build/patch-manifest.json').read_text())['labels']
    start = 16+labels['NextOamIndex']-0x8000
    for index in range(256):
        expected = (index+0xc4) & 255
        while expected < 0x44:
            expected = (expected+0xc4) & 255
        assert rom[start+index] == expected, 'Fast OAM allocation must match the original permutation'
    pointer = int.from_bytes(source[16+0xfbe:16+0xfc0], 'little')
    assert source[16+pointer-0x8000] == 0, 'Native pose zero must remain an empty metasprite'
    assert max(source[16+0x1e46a:16+0x1e46a+2*0x28:2]) <= 20, 'Fireball broad bounds must cover every native enemy'
    for index, original in enumerate([0x1e, 0x20, 0x26, 0x24, 0x2e, 0x30, 0x46, 0x48, 0x58, 0x56, 0x6c, 0x6a]):
        if index in (2, 3):
            continue  # Unused whip slots $60/$62 now hold original food art.
        start = (92+index*2)*16
        native = 0x5018+original*16
        assert custom[start:start+32] == source[native:native+32], 'Native whip graphics must be preserved'
    restored = bytearray(source)
    patch = (ROOT/'build/Mario in Castlevania.ips').read_bytes()
    assert patch[:5] == b'PATCH'
    i = 5
    while patch[i:i+3] != b'EOF':
        offset = int.from_bytes(patch[i:i+3], 'big')
        size = int.from_bytes(patch[i+3:i+5], 'big')
        i += 5
        assert size > 0
        restored[offset:offset+size] = patch[i:i+size]
        i += size
    assert i+3 == len(patch)
    assert bytes(restored) == rom, 'IPS must reproduce the candidate exactly'


def main():
    rom = ROM.read_bytes()
    sha = hashlib.sha256(rom).hexdigest()
    verify_artifact(rom)
    directory = ROOT/'analysis/verification'
    directory.mkdir(parents=True, exist_ok=True)
    motion = subprocess.run([sys.executable, str(ROOT/'tools/verify_motion.py')],
                            cwd=ROOT, text=True, capture_output=True, timeout=90)
    (directory/'motion.log').write_text(motion.stdout+motion.stderr)
    print('SMB motion and fireball comparison:', 'PASS' if motion.returncode == 0 else 'FAIL', flush=True)
    physics = subprocess.run([sys.executable, str(ROOT/'tools/verify_physics.py')],
                             cwd=ROOT, text=True, capture_output=True, timeout=530)
    (directory/'physics-comparison.log').write_text(physics.stdout+physics.stderr)
    print('Full SMB position/subpixel comparison:', 'PASS' if physics.returncode == 0 else 'FAIL', flush=True)
    tiles = subprocess.run([sys.executable, str(ROOT/'tools/verify_tile_lookup.py')],
                           cwd=ROOT, text=True, capture_output=True, timeout=90)
    (directory/'tile-comparison.log').write_text(tiles.stdout+tiles.stderr)
    print('Native terrain lookup comparison:', 'PASS' if tiles.returncode == 0 else 'FAIL', flush=True)
    graphics = subprocess.run([sys.executable, str(ROOT/'tools/verify_native_graphics.py')],
                              cwd=ROOT, text=True, capture_output=True, timeout=90)
    (directory/'native-graphics.log').write_text(graphics.stdout+graphics.stderr)
    print('All original graphics comparison:', 'PASS' if graphics.returncode == 0 else 'FAIL', flush=True)
    results = []
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = {executor.submit(run, name): name for name in SCRIPTS}
        for future in as_completed(futures):
            try:
                result = future.result()
            except Exception as error:
                result = {'name': futures[future], 'passed': False, 'error': str(error)}
            results.append(result)
            print(result['name']+': '+('PASS' if result['passed'] else 'FAIL'), flush=True)
    assert hashlib.sha256(ROM.read_bytes()).hexdigest() == sha, 'Candidate changed during verification'
    report = {'candidate_sha256': sha,
              'verified_at': datetime.now(timezone.utc).isoformat(),
              'motion_passed': motion.returncode == 0, 'tiles_passed': tiles.returncode == 0,
              'graphics_passed': graphics.returncode == 0, 'artifact_passed': True,
              'physics_passed': physics.returncode == 0,
              'tests': sorted(results, key=lambda result: result['name']),
              'limitations': ['Controller-only route ends after the first indoor door; no full-game clear is claimed',
                              'Boss damage uses isolated native handlers; background routes initialize real rooms with directed collision support and are not full-level clears',
                              'Moving platform coverage uses native room initialization with controlled player placement and terrain isolation; it does not claim full platform-level clears']}
    fullgame_path=ROOT/'analysis/fullgame-results.json'
    if fullgame_path.exists():
        fullgame=json.loads(fullgame_path.read_text())
        if fullgame.get('candidate_sha256')==sha and fullgame.get('fresh_boot_verified') and fullgame.get('full_game_clear'):
            report['fullgame_evidence']='analysis/fullgame-results.json'
            report['full_game_clear_passed']=True
            report['limitations'][0]='Regression-suite controller routes end after the first indoor door; the separate continuous full-game controller replay reaches native credits'
    (ROOT/'analysis/verification-results.json').write_text(json.dumps(report, indent=2))
    assert motion.returncode == 0 and physics.returncode == 0 and tiles.returncode == 0 and graphics.returncode == 0 and all(result['passed'] for result in results), 'See analysis/verification logs for failed cases'
    print(f'All {len(results)} emulator checks, exact SMB motion comparisons and artifact checks passed: {sha}')


if __name__ == '__main__':
    main()
