"""Run a bounded native Mesen test; wait for the actual process on Windows."""
import argparse
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('script', type=Path)
parser.add_argument('rom', type=Path)
parser.add_argument('--emulator', default='C:/mesen2/Mesen.exe')
parser.add_argument('--timeout', type=int, default=25, help='Bounded emulator run time in seconds')
args = parser.parse_args()
assert args.timeout > 0, 'Timeout must be positive'
guard = 'TEST_ROOT=[=['+Path(__file__).resolve().parents[1].as_posix()+']=]\n'+'''local originalAssert=assert
function assert(value,message,...)
 if not value then print('FAIL '..tostring(message));emu.stop(1);return originalAssert(value,message) end
 return value,message,...
end
'''
# Keep fixture/controller timelines relative to completed startup. The extra
# CHR bank is prepared while rendering is off; physical loading frames are
# not gameplay frames. This only reads native mode/aux and never changes RAM.
header = args.rom.read_bytes()[:16]
mapper = (header[6] >> 4) | (header[7] & 0xf0)
if mapper == 5:
    guard += '''local rawAddEvent=emu.addEventCallback
local timelineFrame=0
local waitingForStartup=false
rawAddEvent(function()
 if timelineFrame==600 then
  waitingForStartup=emu.read(0x18,emu.memType.nesDebug)~=5 or emu.read(0x19,emu.memType.nesDebug)~=6
 end
 if not waitingForStartup then timelineFrame=timelineFrame+1 end
end,emu.eventType.endFrame)
emu.addEventCallback=function(callback,event)
 if event==emu.eventType.endFrame then
  return rawAddEvent(function() if not waitingForStartup then callback() end end,event)
 end
 return rawAddEvent(callback,event)
end
'''
with tempfile.TemporaryDirectory(prefix='mesen-check-') as directory:
    wrapper = Path(directory)/'guarded-test.lua'
    wrapper.write_text(guard+'dofile([=['+args.script.resolve().as_posix()+']=])\n')
    result = subprocess.run([args.emulator, '--testRunner', '--enableStdout', f'--timeout={args.timeout}', str(wrapper), str(args.rom.resolve())], capture_output=True, text=True, timeout=args.timeout+10)
print(result.stdout)
print(result.stderr)
print('Mesen exit:', result.returncode)
raise SystemExit(result.returncode)
