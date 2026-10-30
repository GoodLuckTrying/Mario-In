"""Run a bounded, headless native Mesen Lua verification."""
from pathlib import Path
import argparse,subprocess,tempfile
parser=argparse.ArgumentParser()
parser.add_argument('script',type=Path)
parser.add_argument('--rom',type=Path,default=Path('dist/Mario in Kid Icarus.nes'))
parser.add_argument('--timeout',type=int,default=25)
parser.add_argument('--define',action='append',default=[])
args=parser.parse_args()
prefix="""local originalAssert=assert
function assert(value,message,...)
 if not value then print('FAIL '..tostring(message));emu.stop(1);return originalAssert(value,message) end
 return value,message,...
end
"""
for definition in args.define:prefix+=definition+'\n'
prefix+='TEST_ROOT=[=['+Path(__file__).resolve().parents[1].as_posix()+']=]\n'
with tempfile.TemporaryDirectory(prefix='icarus-test-') as temp:
    script=Path(temp)/'run.lua'
    script.write_text(prefix+'dofile([=['+args.script.resolve().as_posix()+']=])\n')
    result=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout',f'--timeout={args.timeout}',str(script),str(args.rom.resolve())],capture_output=True,text=True,timeout=args.timeout+10)
print(result.stdout);print(result.stderr)
raise SystemExit(result.returncode)
