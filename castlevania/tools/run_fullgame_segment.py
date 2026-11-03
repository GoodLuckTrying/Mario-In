"""Branch only with opaque Mesen checkpoints and actual controller inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ROM = Path('C:/nes/Mario In/Mario in Castlevania.nes')
parser = argparse.ArgumentParser()
parser.add_argument('checkpoint', type=Path)
parser.add_argument('name')
parser.add_argument('--frames', type=int, default=600)
parser.add_argument('--inputs', default='R+B')
parser.add_argument('--policy', type=Path)
parser.add_argument('--timeout', type=int, default=90)
parser.add_argument('--rom', type=Path, default=ROM)
parser.add_argument('--allow-death', action='store_true', help='Continue ordinary death/respawn using controller input')
args = parser.parse_args()
ROM = args.rom.resolve()
output = ROOT/'analysis/fullgame'/args.name
assert not output.with_suffix('.state').exists(), 'Preserve prior checkpoint artifacts'
config = {
    'checkpoint': args.checkpoint.resolve().as_posix(),
    'output': output.as_posix(), 'frames': args.frames,
    'inputs': args.inputs,
    'allow_death': args.allow_death,
    'policy': args.policy.resolve().as_posix() if args.policy else None,
    'rom_sha256': hashlib.sha256(ROM.read_bytes()).hexdigest(),
}
output.with_suffix('.config.json').write_text(json.dumps(config, indent=2))
def lua(v):
    if v is None: return 'nil'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, dict): return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
    return json.dumps(v)
script = output.parent / (output.name+'-run.lua')
assert not args.policy or script.resolve()!=args.policy.resolve(), 'Keep runner and policy files separate'
script.write_text('FULLGAME='+lua(config)+'\n'
                  +"local nativeAssert=assert\nfunction assert(v,m,...) if not v then print('FAIL '..tostring(m));emu.stop(1) end return nativeAssert(v,m,...) end\n"
                  +'dofile([=['+(ROOT/'tests/fullgame_segment.lua').as_posix()+']=])\n')
result = subprocess.run(['C:/mesen2/Mesen.exe', '--testRunner', '--enableStdout',
                         f'--timeout={args.timeout}', '--doNotSaveSettings',
                         str(script), str(ROM)], capture_output=True, text=True,
                        timeout=args.timeout+15)
output.with_suffix('.log').write_text(result.stdout+result.stderr+f'\nMesen exit: {result.returncode}\n')
assert hashlib.sha256(ROM.read_bytes()).hexdigest()==config['rom_sha256'], 'ROM changed during playback'
print('\n'.join(line for line in result.stdout.splitlines()
                if line.startswith(('step ', 'Checkpoint ', 'FAIL ', 'Error', 'Lua'))))
print('Mesen exit:', result.returncode)
sys.exit(result.returncode)
