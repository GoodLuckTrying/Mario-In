from pathlib import Path
import argparse,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('script',type=Path);p.add_argument('--rom',type=Path,default=ROOT/'dist/Mario in Gradius.nes');p.add_argument('--define',action='append',default=[]);p.add_argument('--timeout',type=int,default=30);a=p.parse_args()
prefix='''local originalAssert=assert
function assert(value,message,...)
 if not value then print('FAIL '..tostring(message));emu.stop(1);return originalAssert(value,message) end
 return value,message,...
end
'''
prefix+='TEST_ROOT=[=['+ROOT.as_posix()+']=]\n'+'\n'.join(a.define)+'\n'
if (ROOT/'build/manifest.json').exists():
 manifest=json.loads((ROOT/'build/manifest.json').read_text())
 for table,key in [('H','labels'),('N','native')]:
  prefix+=table+'={'+','.join('["'+k+'"]='+str(v) for k,v in manifest.get(key,{}).items())+'}\n'
prefix+='''emu.setInput({a=true},1,0)
local standardInput=emu.getInput(1).a
emu.setInput({a=false},0,0)
emu.setInput({a=false},1,0)
function setPad(port,buttons)
 if standardInput then emu.setInput(buttons,port,0)
 else emu.setInput(buttons,0,port) end
end
'''
with tempfile.TemporaryDirectory(prefix='gradius-test-') as temp:
 script=Path(temp)/'run.lua';script.write_text(prefix+'dofile([=['+a.script.resolve().as_posix()+']=])\n')
 r=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout',f'--timeout={a.timeout}',str(script),str(a.rom.resolve())],capture_output=True,text=True,timeout=a.timeout+10)
print(r.stdout);print(r.stderr);raise SystemExit(r.returncode)
