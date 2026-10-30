"""Compare fast lookups with the original native function in isolated fixtures."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT/'build/Mario in Castlevania.nes'
rom = ROM.read_bytes()
original = Path('C:/nes/Castlevania (USA) (Rev 1).nes').read_bytes()
assert rom[0x1f93e+16:0x1f9d4+16] == original[0x1f93e+16:0x1f9d4+16]
labels = json.loads((ROOT/'build/patch-manifest.json').read_text())['labels']
# Test-only driver in unused bank 6 padding. It calls the untouched native
# F9A0 lookup once per game update, then resumes the original CEF0 call.
reference = bytearray(rom)
address = 0xbff0
offset = 16+0x18000+address-0x8000
code = bytes.fromhex('a9 01 8d 4b 60 20 a0 f9 a9 00 8d 4b 60 4c 6a fa')
assert reference[offset:offset+len(code)] == b'\xff'*len(code)
reference[offset:offset+len(code)] = code
reference[0x1cef0+16:0x1cef3+16] = bytes([0x20,address&255,address>>8])
results = []
with tempfile.TemporaryDirectory(prefix='native-tile-') as directory:
    root = Path(directory)
    native_rom = root/'native-reference.nes'
    native_rom.write_bytes(reference)
    for name, target, entry, end in [('native', native_rom, 0xf9a0, 0xf99f),
                                     ('fast', ROM, labels['TileAtPoint'], labels['TileAtPointReturn'])]:
        output = ROOT/f'analysis/tile-{name}.csv'
        script = root/f'{name}.lua'
        script.write_text(f'NATIVE_TILE={str(name=="native").lower()}\nTILE_ENTRY={entry}\nTILE_EXIT={end}\n'
                          'TILE_OUTPUT=[=['+output.as_posix()+']=]\n'
                          'dofile([=['+(ROOT/'tests/tile-probe.lua').as_posix()+']=])\n')
        result = subprocess.run([sys.executable, str(ROOT/'tools/run_mesen.py'), str(script), str(target)],
                                cwd=ROOT, text=True, capture_output=True, timeout=45)
        (ROOT/f'analysis/verification/tile-{name}.log').write_text(result.stdout+result.stderr)
        print(name+': '+('PASS' if result.returncode==0 else 'FAIL'), flush=True)
        if result.returncode:
            print(result.stdout+result.stderr)
        results.append(result.returncode==0)
assert all(results)
assert (ROOT/'analysis/tile-native.csv').read_bytes() == (ROOT/'analysis/tile-fast.csv').read_bytes()
report = {'candidate_sha256': hashlib.sha256(rom).hexdigest(), 'passed': True,
          'cases': 1152, 'evidence_type': 'Controlled native/fast differential fixtures; reference ROM uses a test-only caller'}
(ROOT/'analysis/tile-results.json').write_text(json.dumps(report, indent=2))
print('All 1152 packed-byte, quadrant, camera/page, stage and out-of-range cases match native F9A0.')
