"""Compare every native sprite's pixels across every native CHR load command."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile
from native_graphics import metasprites, sprite_remap

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT/'build/Mario in Castlevania.nes'
original = Path('C:/nes/Castlevania (USA) (Rev 1).nes').read_bytes()
candidate = ROM.read_bytes()
labels = json.loads((ROOT/'build/patch-manifest.json').read_text())['labels']
with tempfile.TemporaryDirectory(prefix='native-art-') as directory:
    directory = Path(directory)
    for name, data, entry in [('original',original,0xfd23),
                               ('candidate',candidate,labels['PrepareNativeChr'])]:
        test = bytearray(data)
        # Test-only caller in unused bank-six padding, reached after native AI.
        address = 0xbfe4
        offset = 16+0x18000+address-0x8000
        code = bytes.fromhex('ad c0 07 c9 ff f0 08 20')+entry.to_bytes(2,'little')+bytes.fromhex('a9 ff 8d c0 07 4c 76 f3')
        assert test[offset:offset+len(code)] == b'\xff'*len(code)
        test[offset:offset+len(code)] = code
        test[16+0x1cf1f:16+0x1cf22] = bytes([0x20,address&255,address>>8])
        target = directory/f'{name}.nes'
        target.write_bytes(test)
        script = directory/f'{name}.lua'
        # Normalize unused power-on CHR bytes; all actual graphics are loaded
        # by native code. Different ROM hashes otherwise randomize these holes.
        script.write_text('for a=0,'+str(0x3fff if name=='candidate' else 0x1fff)+' do emu.write(a,0,emu.memType.nesChrRam) end\n'+'''local frame=0
local command=0
local pending=false
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function w(a,v) emu.write(a,v,emu.memType.nesDebug) end
emu.addEventCallback(function() emu.setInput({start=frame==120},0) end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 if frame<700 or r(0x18)~=5 or r(0x19)~=6 then w(0x7c0,255);return end
 if not pending and command<11 then w(0x7c0,command);pending=true end
end,emu.callbackType.exec,0xcf1f)
emu.addMemoryCallback(function()
 if not pending then return end
 assert(r(0x7c0)==255,'CHR load must return to native engine')
 local file=assert(io.open([=['''+directory.as_posix()+f'/{name}-'+''']=]..command..'.chr','wb'))
 for a=0,'''+str(0x3fff if name=='candidate' else 0x1fff)+''' do file:write(string.char(emu.read(a,emu.memType.nesChrRam))) end
 file:close();print('Captured native CHR command '..command)
 command=command+1;pending=false
 if command==11 then emu.stop(0) end
end,emu.callbackType.exec,0xcf22)
emu.addEventCallback(function() frame=frame+1;if frame==2400 then assert(false,'Graphics audit timeout') end end,emu.eventType.endFrame)
''')
        result = subprocess.run([sys.executable,str(ROOT/'tools/run_mesen.py'),str(script),str(target)],
                                capture_output=True,text=True,timeout=45)
        (ROOT/f'analysis/verification/graphics-{name}.log').write_text(result.stdout+result.stderr)
        assert result.returncode==0, result.stdout+result.stderr
    mapping = sprite_remap(original)
    poses = metasprites(original)
    tiles = {record['tile'] for pose in poses for record in pose}
    for command in range(11):
        native = (directory/f'original-{command}.chr').read_bytes()
        patched = (directory/f'candidate-{command}.chr').read_bytes()
        if patched[:8192]!=native:
            (ROOT/'analysis/native-art-reference.chr').write_bytes(native)
            (ROOT/'analysis/native-art-candidate.chr').write_bytes(patched)
            diffs=[(i,native[i],patched[i]) for i in range(8192) if native[i]!=patched[i]]
            raise AssertionError(f'Original background CHR differs for command {command}: {len(diffs)} bytes; first {diffs[:10]}')
        for tile in tiles:
            relocated = mapping.get(tile,tile)
            source = (tile%2)*4096+(tile&254)*16
            dest = 8192+(relocated%2)*4096+(relocated&254)*16
            assert native[source:source+32]==patched[dest:dest+32], f'Native sprite {tile:02X} differs for command {command}'
        # Native direct OAM graphics not represented in the pose table.
        for tile in (0x52,0x54,0xfc,0xfe):
            relocated=mapping.get(tile,tile)
            source=(tile%2)*4096+(tile&254)*16
            dest=8192+(relocated%2)*4096+(relocated&254)*16
            assert native[source:source+32]==patched[dest:dest+32]
report={'candidate_sha256':hashlib.sha256(candidate).hexdigest(),'passed':True,
        'native_poses':len(poses),'graphics_commands':11,'background_bytes_per_command':8192,
        'evidence_type':'Actual native CHR-load differential fixtures using a test-only caller; no gameplay clear claimed'}
(ROOT/'analysis/native-graphics-results.json').write_text(json.dumps(report,indent=2))
print(f'All {len(poses)} native poses, direct HUD/object tiles and complete background banks preserve original pixels for all 11 graphics commands.')

