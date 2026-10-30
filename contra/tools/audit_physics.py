"""Audit the installed Contra port against assembled local smb1base source.

Read-only with respect to ROMs and game source. Builds a standalone reference
from verbatim SMB movement routines, then executes both engines under py65.
Terrain fixtures isolate land movement; no camera, enemies or host water rules.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import sys
from py65.devices.mpu6502 import MPU

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT.parent / 'vendor/smb1base'
OUT = ROOT / 'build/physics-audit'
sys.path.insert(0, str(ROOT.parent / 'tools'))
from verify_physics import run, set_values


def reference():
    player = (BASE / 'src/player.s').read_text()
    common = (BASE / 'src/common.s').read_text()
    def between(text, start, end):
        return text[text.index(start):text.index(end, text.index(start))]
    movement = between(player, 'PlayerMovementSubs:', 'ClimbAdderLow:')
    physics = between(player, 'JumpMForceData:', 'ScrollHandler:')
    vertical = between(player, 'MovePlayerVertically:', '  jmp ImposeGravitySprObj') + '  jmp ImposeGravitySprObj\n'
    horizontal = between(common, 'MovePlayerHorizontally:', ';--------------------------------\n',)
    gravity = between(common, 'ImposeGravitySprObj:', ';--------------------------------\n')
    jump = between(common, '.proc JumpEngine', '.endproc') + '.endproc\n'
    # Include the actual input filtering and moving-direction update from the
    # controller wrapper, which the older MovementSubs-only test did not cover.
    inputs = between(player, 'SaveJoyp:', 'SizeChk:')
    direction = between(player, '  lda #$01                    ;set moving direction', 'PlayerSubs:')
    body = ('AuditStep:\n' + inputs + 'SizeChk:\n jsr PlayerMovementSubs\n' + direction + 'PlayerSubs: rts\n' +
            movement + physics + '\nExPlyrAt: rts\n' + vertical + horizontal + gravity + jump +
            '\nClimbingSub: rts\n')
    # Variable addresses are arbitrary for this isolated source build. Only
    # shared names/aliases and the zero-page indirect jump pointers matter.
    code = '\n'.join(line.split(';')[0] for line in body.splitlines())
    labels = set(re.findall(r'(\w+):|\.proc\s+(\w+)', code))
    labels = {x for pair in labels for x in pair if x}
    names = set()
    for line in code.splitlines():
        m = re.search(r'\b(?:lda|sta|ldx|stx|ldy|sty|adc|sbc|and|ora|eor|cmp|cpx|cpy|inc|dec|asl|lsr|rol|ror|bit)\s+(.*)', line)
        if m:
            names.update(re.findall(r'(?<![$\w])[A-Za-z_]\w*\b', m[1]))
    names -= labels | {'x', 'y', 'A_Button', 'B_Button', 'Sfx_BigJump', 'Sfx_EnemyStomp', 'Sfx_SmallJump'}
    aliases = {'SprObject_X_Speed': 'Player_X_Speed', 'SprObject_PageLoc': 'Player_PageLoc',
               'SprObject_X_MoveForce': 'Position_X_Fraction', 'SprObject_X_Position': 'Player_X_Position',
               'SprObject_Y_MoveForce': 'Player_Y_MoveForce', 'SprObject_Y_Speed': 'Player_Y_Speed',
               'SprObject_Y_Position': 'Player_Y_Position', 'SprObject_Y_HighPos': 'Player_Y_HighPos'}
    names |= set(aliases.values()) | {'RunningTimer', 'JumpSwimTimer', 'ClimbSideTimer', 'SavedJoypadBits'}
    variables = {f'R{i}': i for i in range(8)}
    for name in sorted(names - set(aliases) - set(variables)):
        variables[name] = 0x200 + len(variables)
    for name, target in aliases.items():
        variables[name] = variables[target]
    header = '.setcpu "6502"\nUSE_SMB2J_FEATURES=0\nA_Button=$80\nB_Button=$40\nSfx_BigJump=1\nSfx_EnemyStomp=2\nSfx_SmallJump=3\n'
    header += '\n'.join(f'{name}=${addr:04X}' for name, addr in variables.items())
    exports = ['AuditStep', 'PlayerMovementSubs', 'X_Physics', 'GetPlayerAnimSpeed', 'ImposeFriction']
    assembly = header + '\n.export ' + ','.join(exports) + '\n.segment "CODE"\n' + body
    (OUT / 'reference.s').write_text(assembly)
    (OUT / 'reference.cfg').write_text('MEMORY { ROM: start=$8000, size=$8000, file=%O, fill=yes; }\nSEGMENTS { CODE: load=ROM, type=ro; }\n')
    cc = BASE / 'tools/Windows/cc65/bin'
    subprocess.run([str(cc / 'ca65.exe'), str(OUT / 'reference.s'), '-o', str(OUT / 'reference.o')], check=True)
    subprocess.run([str(cc / 'ld65.exe'), '-C', str(OUT / 'reference.cfg'), str(OUT / 'reference.o'),
                    '-o', str(OUT / 'reference.bin'), '-Ln', str(OUT / 'reference.lbl')], check=True)
    symbols = {m[1]: int(m[0], 16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)', (OUT / 'reference.lbl').read_text())}
    return (OUT / 'reference.bin').read_bytes(), variables, symbols


def main():
    global OUT
    parser=argparse.ArgumentParser();parser.add_argument('--candidate',action='store_true');parser.add_argument('--require-match',action='store_true');options=parser.parse_args()
    if options.candidate:OUT=ROOT/'build/physics-repair'
    OUT.mkdir(parents=True, exist_ok=True)
    code, V, S = reference()
    manifest = json.loads((ROOT / 'build/manifest.json').read_text())
    H, N = manifest['labels'], manifest['native']
    rom_path=(ROOT/'dist/Mario and Luigi in Contra.nes')if options.candidate else Path('C:/nes/Mario and Luigi in Contra.nes')
    installed = rom_path.read_bytes()
    assert hashlib.sha256(installed).hexdigest() == manifest['output_sha256']
    pairs = {'vx': ('Player_X_Speed', 6), 'xforce': ('Player_X_MoveForce', 7),
             'abs': ('Player_XSpeedAbsolute', 8), 'xfrac': ('Position_X_Fraction', 0x16),
             'vy': ('Player_Y_Speed', 0x18), 'vyfrac': ('Player_Y_MoveForce', 0x19),
             'yfrac': ('Player_YMoveForceFractional', 0x17), 'state': ('Player_State', 5),
             'facing': ('PlayerFacingDir', 0xB), 'run': ('RunningSpeed', 9),
             'timer': ('RunningTimer', 0xA), 'fall': ('VerticalForceDown', 0x1B),
             'gravity': ('VerticalForce', 0x1A)}
    results = []
    replay = []
    speeds = [0, 8, 9, 15, 16, 24, 25, 27, 28, 32, 33, 40]
    scenarios = ['walk', 'run', 'release', 'reverse', 'jump-1', 'jump-2', 'jump-8', 'jump-25',
                 'air-turn', 'chain-jump', 'down-direction', 'crouch-direction', 'walk-off', 'fast-jump-walk-off']
    for p in [0, 1]:
      b = 0x6000 + p * 128
      for power in range(3):
       for direction in [1, 2]:
        for scenario in scenarios:
         for initial_speed in (speeds if scenario.startswith('jump-') else [0]):
          smb, port = MPU(), MPU()
          smb.memory[0x8000:] = code
          port.memory[0x8000:0xC000] = installed[16+8*16384:16+9*16384]
          port.memory[0xC000:] = installed[16+15*16384:16+16*16384]
          initial = {'PlayerFacingDir': direction, 'Player_MovingDir': direction, 'AreaType': 1,
                     'GameEngineSubroutine': 8, 'PlayerSize': int(power == 0), 'Player_CollisionBits': 3,
                     'Player_X_Position': 128, 'Player_Y_Position': 144, 'Player_Y_HighPos': 1,
                     'VerticalForceDown': 0x70, 'Player_X_Speed': initial_speed if direction == 1 else -initial_speed,
                     'Player_XSpeedAbsolute': initial_speed}
          set_values(smb, {V[k]: val for k, val in initial.items()})
          set_values(port, {b: 0x4D, b+4: power, b+0xB: direction, b+0xC: direction, b+0x14: 1,
                           b+0x15: 8, b+0x1B: 0x70, b+0x20: 255,
                           b+6: initial_speed if direction == 1 else -initial_speed, b+8: initial_speed,
                           N['SPRITE_X_POS']+p: 128, N['SPRITE_Y_POS']+p: 164, N['PLAYER_STATE']+p: 1, 0x6101: p})
          floor = True
          def terrain(c):
              c.a = 0x80 if floor and c.y >= 176 else 0
              c.p = (c.p & ~0x83) | (c.a & 0x80) | (2 if c.a == 0 else 0)
          def tile(c):
              c.y = c.a
              terrain(c)
          def native_x(c):
              address = N['SPRITE_X_POS']+p
              c.memory[address] = (c.memory[address] + c.memory[N['PLAYER_X_VELOCITY']+p]) & 255
          traps = {N['get_bg_collision']: terrain, H[f'P{p}Tile']: tile, N['calc_player_x_vel']: native_x}
          first = None
          matched = 0
          landed = False
          max_rise = [0, 0]
          max_x = [0, 0]
          trace = []
          for tick in range(140):
              held = direction
              if scenario in ['run', 'release', 'reverse', 'air-turn', 'chain-jump', 'fast-jump-walk-off']:
                  held |= 0x40
              if scenario == 'release' and tick >= 50: held = 0
              if scenario == 'reverse' and tick >= 50: held = (direction ^ 3) | 0x40
              if scenario.startswith('jump-'):
                  held = 0x80 if tick < int(scenario.split('-')[1]) else 0
              if scenario == 'air-turn' and tick >= 30: held = (direction ^ 3) | (0x80 if tick < 55 else 0)
              if scenario == 'chain-jump' and tick % 65 >= 30 and tick % 65 < 55: held |= 0x80
              if scenario == 'down-direction': held = direction | 4
              if scenario == 'crouch-direction': held = 4 if tick < 10 else direction | 4
              if scenario == 'walk-off' and tick >= 30: floor = False
              if scenario == 'fast-jump-walk-off':
                  if 65 <= tick < 90: held |= 0x80
                  if landed: floor = False
              for name in ['RunningTimer', 'JumpSwimTimer', 'ClimbSideTimer']:
                  if smb.memory[V[name]]: smb.memory[V[name]] -= 1
              smb.memory[V['SavedJoypadBits']] = held
              smb.memory[V['Player_X_Position']] = 128
              port.memory[N['SPRITE_X_POS']+p] = 128
              port.memory[N['CONTROLLER_STATE']+p] = held
              # Support disappears before the movement step, as SMB's previous
              # background collision would have set the falling state.
              if not floor and smb.memory[V['Player_State']] == 0:
                  smb.memory[V['Player_State']] = 2
              run(smb, S['AuditStep'])
              run(port, H[f'P{p}Move'], traps)
              airborne = smb.memory[V['Player_State']] != 0
              if floor and smb.memory[V['Player_Y_Position']] >= 144 and smb.memory[V['Player_Y_Speed']] < 128:
                  # Match the existing flat-floor differential fixture.
                  for name in ['Player_State', 'Player_Y_Speed', 'Player_Y_MoveForce', 'Player_YMoveForceFractional']:
                      smb.memory[V[name]] = 0
                  smb.memory[V['Player_Y_Position']] = 144
                  if tick > 65 and airborne: landed = True
              diffs = {k: [smb.memory[V[name]], port.memory[b+off]] for k, (name, off) in pairs.items()
                       if smb.memory[V[name]] != port.memory[b+off]}
              sy = smb.memory[V['Player_Y_Position']]
              py = port.memory[N['SPRITE_Y_POS']+p]
              if (sy+20) & 255 != py: diffs['y'] = [(sy+20) & 255, py]
              sx = smb.memory[V['Player_X_Position']]
              px = port.memory[N['SPRITE_X_POS']+p]
              if sx != px: diffs['x'] = [sx, px]
              if bool(smb.memory[V['CrouchingFlag']]) != bool(port.memory[b+0x1D]):
                  diffs['crouch'] = [int(bool(smb.memory[V['CrouchingFlag']])), port.memory[b+0x1D]]
              max_rise[0] = max(max_rise[0], 144-sy)
              max_rise[1] = max(max_rise[1], 164-py)
              max_x[0] = max(max_x[0], abs(sx-128))
              max_x[1] = max(max_x[1], abs(px-128))
              if diffs and first is None: first = {'tick': tick, 'held': held, 'differences': diffs}
              if not diffs: matched += 1
              trace.append({'held': held, 'floor': floor, 'port': [port.memory[b+i] for i in range(0x1F)],
                            'x': px, 'y': py, 'source_vy': smb.memory[V['Player_Y_Speed']],
                            'source_vyfrac': smb.memory[V['Player_Y_MoveForce']], 'source_y': (sy+20)&255})
              smb.memory[V['PreviousA_B_Buttons']] = held & 0xC0
          results.append({'player': p, 'power': power, 'direction': direction, 'scenario': scenario,
                          'initial_speed': initial_speed, 'updates': 140, 'matched': matched,
                          'first_difference': first, 'max_rise': max_rise, 'max_pixel_step': max_x})
          if power in [0, 2] and direction == 1 and initial_speed == 0 and scenario in ['run', 'jump-1', 'jump-25', 'down-direction', 'fast-jump-walk-off']:
              replay.append({'player': p, 'power': power, 'scenario': scenario, 'trace': trace})
    report = {'rom_sha256': hashlib.sha256(installed).hexdigest(),
              'reference': 'Verbatim movement/input/gravity routines from local vendor/smb1base; USE_SMB2J_FEATURES=0',
              'source_sha256': {name: hashlib.sha256((BASE/'src'/name).read_bytes()).hexdigest() for name in ['player.s', 'common.s']},
              'cases': len(results), 'updates': sum(x['updates'] for x in results),
              'matching_cases': sum(x['first_difference'] is None for x in results), 'results': results}
    (OUT/'results.json').write_text(json.dumps(report, indent=2))
    # Lua fixtures contain measured CPU-engine expectations, not new gameplay
    # instructions. The Mesen replay checks the same instructions in the ROM.
    def lua(value):
        if isinstance(value, bool): return str(value).lower()
        if isinstance(value, int): return str(value)
        if isinstance(value, str): return json.dumps(value)
        if isinstance(value, list): return '{'+','.join(lua(x) for x in value)+'}'
        return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    (OUT/'fixtures.lua').write_text('return '+lua(replay)+'\n')
    summary = {}
    for row in results:
        group = summary.setdefault(row['scenario'], {'cases': 0, 'matches': 0, 'examples': []})
        group['cases'] += 1
        group['matches'] += row['first_difference'] is None
        if row['first_difference'] and len(group['examples']) < 2: group['examples'].append(row)
    print(json.dumps({'cases': report['cases'], 'updates': report['updates'], 'matching_cases': report['matching_cases'], 'scenarios': summary}, indent=2))
    if options.require_match:assert report['matching_cases']==report['cases'],'Candidate differs from SMB1 source'
    print('PASS source differential comparisons')


if __name__ == '__main__':
    main()
