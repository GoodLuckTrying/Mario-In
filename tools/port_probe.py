"""Run an isolated Mesen research/replay script for a native port."""
from pathlib import Path
import argparse,json,subprocess,tempfile
BASE=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('game');p.add_argument('script',type=Path);p.add_argument('--rom',type=Path);p.add_argument('--timeout',type=int,default=40);p.add_argument('--define',action='append',default=[]);a=p.parse_args()
root=BASE/a.game
names={'kungfu':'Kung Fu (Japan, USA) (En).nes','snake':'Snake Rattle n Roll (USA).nes'}
rom=a.rom or Path('C:/nes')/names[a.game]
prefix='TEST_ROOT=[=['+root.as_posix()+']=]\n'+'\n'.join(a.define)+'\n'
prefix+='''local originalAssert=assert
function assert(value,message,...)
 if not value then print('FAIL '..tostring(message));emu.stop(1);return originalAssert(value,message) end
 return value,message,...
end
emu.setInput({a=true},1,0)
local standardInput=emu.getInput(1).a
emu.setInput({a=false},0,0);emu.setInput({a=false},1,0)
function setPad(port,buttons)
 if standardInput then emu.setInput(buttons,port,0)
 else emu.setInput(buttons,0,port) end
end
'''
manifest=root/'build/manifest.json'
if manifest.exists():
 v=json.loads(manifest.read_text())
 for table,key in [('H','labels'),('N','native')]:prefix+=table+'={'+','.join('["'+k+'"]='+str(x) for k,x in v.get(key,{}).items())+'}\n'
with tempfile.TemporaryDirectory(prefix=a.game+'-test-') as temp:
 if a.game=='kungfu' and a.rom and 'Mario in Kung Fu' in a.rom.name:
  prefix+='dofile([=['+(root/'tests/graphics_oracle.lua').as_posix()+']=])\n'
 if a.game=='snake' and a.rom and 'Mario and Luigi' in a.rom.name:
  prefix+='dofile([=['+(root/'tests/graphics_oracle.lua').as_posix()+']=])\n'
 script=Path(temp)/'run.lua';script.write_text(prefix+'dofile([=['+a.script.resolve().as_posix()+']=])\n')
 r=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout',f'--timeout={a.timeout}',str(script),str(rom.resolve())],capture_output=True,text=True,timeout=a.timeout+10)
print(r.stdout);print(r.stderr);raise SystemExit(r.returncode)
