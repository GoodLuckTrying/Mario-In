"""Capture the verified power-on controller replay using Mesen's native AVI API.

The bridge starts/stops recording only; the existing replay Lua checks every
checkpoint. No saved state is loaded and no game memory or registers are changed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'analysis/fullgame'
parser = argparse.ArgumentParser()
parser.add_argument('endpoint', nargs='?', default='stage18-credits')
parser.add_argument('--timeout', type=int, default=1200)
args = parser.parse_args()
manifest = json.loads((FOLDER / (args.endpoint + '-route.json')).read_text())
rom = Path('C:/nes/Mario In/Mario in Castlevania.nes')
inputs = FOLDER / (args.endpoint + '-composed-input.csv')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(rom) == manifest['rom_sha256']
assert manifest['full_game_clear'] and manifest['fresh_boot_verified']
input_sha = sha(inputs)
bridge = ROOT / 'build/mesen_capture_bridge.dll'
subprocess.run(['gcc', '-shared', '-O2', '-Wall', '-Wextra',
                '-Wno-cast-function-type', '-o', str(bridge),
                str(ROOT / 'tools/mesen_capture_bridge.c')], check=True)
output = FOLDER / (args.endpoint + '-video')
script = output.with_suffix('.lua')
avi = output.with_suffix('.avi')
fresh = (FOLDER / (args.endpoint + '-fresh.lua')).read_text()
fresh = re.sub(r'^OUTPUT=.*$', 'OUTPUT=' + json.dumps(output.as_posix()), fresh,
               count=1, flags=re.MULTILINE)
setup = '''
local bridge=BRIDGE
local captureBegin=assert(package.loadlib(bridge,'luaopen_capture_start'))
local captureFinish=assert(package.loadlib(bridge,'luaopen_capture_stop'))
local completedFrames=0
emu.addEventCallback(function() completedFrames=completedFrames+1 end,emu.eventType.endFrame)
captureBegin()
'''.replace('BRIDGE', json.dumps(bridge.as_posix()))
fresh = fresh.replace('local polls=0;local boundary=1',
                      'local polls=0;local boundary=1\n' + setup, 1)
fresh = fresh.replace('emu.stop(1)', 'captureFinish();emu.stop(1)')
fresh = fresh.replace('emu.stop(0)',
                      "print('CAPTURE completed frames: '..completedFrames);captureFinish();emu.stop(0)")
assert 'loadSavestate' not in fresh and 'emu.write' not in fresh
script.write_text(fresh)
env = os.environ.copy()
env['MARIO_CASTLEVANIA_CAPTURE_AVI'] = avi.as_posix()
start = time.monotonic()
with output.with_suffix('.log').open('w') as log:
    process = subprocess.Popen(['C:/mesen2/Mesen.exe', '--testRunner', '--enableStdout',
                                f'--timeout={args.timeout}', '--doNotSaveSettings',
                                str(script), str(rom)], stdout=log, stderr=subprocess.STDOUT,
                               env=env)
    print(f'Native recording process: {process.pid}', flush=True)
    seen = ''
    while process.poll() is None:
        if time.monotonic() - start > args.timeout + 15:
            process.terminate()
            process.wait()
            raise TimeoutError('Native capture exceeded its bound')
        trace = output.parent / (output.name + '-trace.csv')
        if trace.exists():
            lines = trace.read_text().splitlines()
            if len(lines) > 1 and lines[-1] != seen:
                seen = lines[-1]
                values = seen.split(',')
                print(f'Checked input {values[0]}/{manifest["input_frames"]}, '
                      f'stage {values[2]}, HP {values[6]}', flush=True)
        time.sleep(5)
    code = process.returncode
log_text = output.with_suffix('.log').read_text()
assert code == 0, log_text[-2000:]
assert f'Fresh-power-on route verified: {manifest["input_frames"]} controller polls' in log_text
assert log_text.count('PASS ') == len(manifest['segments'])
assert 'CAPTURE START: active=1' in log_text and 'CAPTURE STOP' in log_text
assert sha(rom) == manifest['rom_sha256'] and sha(inputs) == input_sha
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
                                           '-show_format', '-of', 'json', str(avi)]))
video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
audio = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
video_seconds = float(video['duration'])
audio_seconds = int(audio['nb_frames']) / int(audio['sample_rate'])
assert abs(video_seconds - audio_seconds) < 0.1, (video_seconds, audio_seconds)
report = {
    'rom_sha256': sha(rom), 'controller_input_sha256': input_sha,
    'controller_polls': manifest['input_frames'], 'checkpoints': len(manifest['segments']),
    'fresh_boot_verified': True, 'full_game_clear': True,
    'capture': 'Mesen native framebuffer and PCM audio via AviRecord export',
    'emulator_sha256': sha(Path('C:/mesen2/Mesen.exe')),
    'emulator_core_sha256': sha(Path('C:/mesen2/MesenCore.dll')),
    'native_video_frames': int(video['nb_frames']),
    'native_frame_rate': video['avg_frame_rate'],
    'native_resolution': [video['width'], video['height']],
    'native_audio_samples_per_channel': int(audio['nb_frames']),
    'native_audio_sample_rate': int(audio['sample_rate']),
    'native_video_seconds': video_seconds, 'native_audio_seconds': audio_seconds,
    'capture_log': output.with_suffix('.log').as_posix(),
    'capture_script': script.as_posix(), 'avi': avi.as_posix(),
}
output.with_suffix('.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2), flush=True)
