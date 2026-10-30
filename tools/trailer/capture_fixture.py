"""Capture native video/audio from a bounded emulator fixture for the trailer."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('game');p.add_argument('fixture');p.add_argument('--define',action='append',default=[]);p.add_argument('--limit',type=int,default=5000);a=p.parse_args()
project=ROOT/a.game
item=next(x for x in json.loads((ROOT/'release/catalog.json').read_text())['patches']if x['game']==a.game)
rom=project/('build'if a.game=='castlevania'else'dist')/(item['name']+'.nes')
assert hashlib.sha256(rom.read_bytes()).hexdigest()==item['rom_sha256']
out=ROOT/'build/trailer/captures';out.mkdir(parents=True,exist_ok=True)
tag=a.game+'-'+Path(a.fixture).stem
bridge=ROOT/'build/trailer/mesen_capture_bridge.dll'
meta=project/('build/patch-manifest.json'if a.game=='castlevania'else'build/manifest.json');j=json.loads(meta.read_text())
lines=['TEST_ROOT=[=['+project.as_posix()+']=]']+a.define
for name,key in [('H','labels'),('N','native')]:lines.append(name+'={'+','.join('['+json.dumps(k)+']='+str(v) for k,v in j.get(key,{}).items())+'}')
lines.append(r'''local rawStop=emu.stop
local originalAssert=assert
local begin=assert(package.loadlib([=[BRIDGE]=],'luaopen_capture_start'))
local finish=assert(package.loadlib([=[BRIDGE]=],'luaopen_capture_stop'))
begin()
emu.stop=function(code)finish();rawStop(code)end
assert=function(ok,message,...)
 if not ok then print('FAIL '..tostring(message));emu.stop(1);return originalAssert(ok,message)end
 return ok,message,...
end
emu.setInput({a=true},1,0)
local standardInput=emu.getInput(1).a
emu.setInput({a=false},0,0);emu.setInput({a=false},1,0)
function setPad(port,buttons)
 if standardInput then emu.setInput(buttons,port,0)else emu.setInput(buttons,0,port)end
end
local frames=0
emu.addEventCallback(function()
 frames=frames+1
 if frames>=FRAME_BOUND then print('CAPTURE LIMIT '..frames);emu.stop(0)end
end,emu.eventType.endFrame)
'''.replace('BRIDGE',bridge.as_posix()).replace('FRAME_BOUND',str(a.limit)))
if a.game in ('kungfu','snake'):lines.append('dofile(TEST_ROOT.."/tests/graphics_oracle.lua")')
if a.game=='castlevania':
 runner=(project/'tools/run_mesen.py').read_text();start=runner.index("    guard += '''")+len("    guard += '''");end=runner.index("'''",start);lines.append(runner[start:end])
fixture=project/a.fixture
script=out/(tag+'.lua');script.write_text('\n'.join(lines)+'\ndofile([=['+fixture.as_posix()+']=])\n')
env=os.environ.copy();env['MARIO_IN_CAPTURE_AVI']=(out/(tag+'.avi')).as_posix()
r=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout','--timeout=90','--doNotSaveSettings',str(script),str(rom)],env=env,capture_output=True,text=True,timeout=100)
(out/(tag+'.log')).write_text(r.stdout+'\n'+r.stderr)
assert r.returncode==0 and 'FAIL 'not in r.stdout,r.stdout[-1800:]+r.stderr[-500:]
assert 'CAPTURE START: active=1'in r.stderr and 'CAPTURE STOP'in r.stderr
(out/(tag+'.json')).write_text(json.dumps(dict(game=a.game,fixture=a.fixture,defines=a.define,rom_sha256=item['rom_sha256'],native_capture=True,fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest()),indent=2)+'\n')
print('CAPTURED '+tag,flush=True)
