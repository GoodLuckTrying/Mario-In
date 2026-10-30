"""Verify a composed route from power-on, without loading any checkpoints."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'analysis/fullgame'
parser=argparse.ArgumentParser();parser.add_argument('endpoint');parser.add_argument('--timeout',type=int,default=180)
parser.add_argument('--rom',type=Path,default=Path('C:/nes/Mario in Castlevania.nes'))
args=parser.parse_args()
manifest=json.loads((folder/(args.endpoint+'-route.json')).read_text())
rom=args.rom.resolve()
assert hashlib.sha256(rom.read_bytes()).hexdigest()==manifest['rom_sha256']
boundaries=[];count=0
for name in manifest['segments']:
    meta=json.loads((folder/(name+'.json')).read_text());count+=meta['input_frames']
    boundaries.append({'name':name,'input':count,'stage':meta['stage'],'room':meta['room'],
                       'x':meta.get('x',meta.get('world_x')),'y':meta['y'],'health':meta['health'],'power':meta['power']})
def lua(v):
    if isinstance(v,dict):return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    return json.dumps(v)
output=folder/(args.endpoint+'-fresh')
script=output.with_suffix('.lua')
script.write_text('BOUNDARIES='+lua(boundaries)+'\nINPUT='+lua((folder/(args.endpoint+'-composed-input.csv')).as_posix())+'\nOUTPUT='+lua(output.as_posix())+'\n'+r'''
local inputs={}
local f=assert(io.open(INPUT,'r'));f:read('*l')
for line in f:lines() do local n,m=line:match('(%d+),(%d+)');inputs[tonumber(n)]=tonumber(m) end
f:close()
local polls=0;local boundary=1
local log=assert(io.open(OUTPUT..'-trace.csv','w'));log:write('input,mode,stage,room,x,y,health,power\n')
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function capture(tag)
 local f=assert(io.open(OUTPUT..tag..'.png','wb'));f:write(emu.takeScreenshot());f:close()
end
emu.addEventCallback(function()
 polls=polls+1
 local m=inputs[polls] or 0
 emu.setInput({a=m&128~=0,b=m&64~=0,select=m&32~=0,start=m&16~=0,up=m&8~=0,down=m&4~=0,left=m&2~=0,right=m&1~=0},0)
end,emu.eventType.inputPolled)
emu.addMemoryCallback(function()
 local c=BOUNDARIES[boundary]
 if not c or polls<c.input then return end
 local x=r(0x40)+256*r(0x41)
 log:write(string.format('%d,%d,%d,%d,%d,%d,%d,%d\n',polls,r(0x18),r(0x28),r(0x46),x,r(0x3f),r(0x45),r(0x6001)));log:flush()
 local ok=polls==c.input and r(0x28)==c.stage and r(0x46)==c.room and x==c.x and r(0x3f)==c.y and r(0x45)==c.health and r(0x6001)==c.power
 print((ok and 'PASS ' or 'FAIL ')..c.name..' input '..polls..' stage '..r(0x28)..' room '..r(0x46)..' x '..x..' y '..r(0x3f)..' HP '..r(0x45)..' power '..r(0x6001))
 if not ok then capture('-mismatch');log:close();emu.stop(1);return end
 boundary=boundary+1
 if not BOUNDARIES[boundary] then
  capture('');local f=assert(io.open(OUTPUT..'.state','wb'));f:write(emu.createSavestate());f:close()
  print('Fresh-power-on route verified: '..polls..' controller polls');log:close();emu.stop(0)
 end
end,emu.callbackType.exec,0xc0b5)
''')
result=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout',f'--timeout={args.timeout}',
                       '--doNotSaveSettings',str(script),str(rom)],capture_output=True,text=True,timeout=args.timeout+15)
output.with_suffix('.log').write_text(result.stdout+result.stderr+f'\nMesen exit: {result.returncode}\n')
assert hashlib.sha256(rom.read_bytes()).hexdigest()==manifest['rom_sha256']
print('\n'.join(x for x in result.stdout.splitlines() if x.startswith(('PASS ','FAIL ','Fresh-power'))))
print('Mesen exit:',result.returncode)
if result.returncode==0 and f'Fresh-power-on route verified: {count} controller polls' in result.stdout:
    manifest['fresh_boot_verified']=True
    manifest['fresh_replay_log']=output.with_suffix('.log').as_posix()
    manifest['verified_controller_polls']=count
    (folder/(args.endpoint+'-route.json')).write_text(json.dumps(manifest,indent=2))
raise SystemExit(result.returncode)
