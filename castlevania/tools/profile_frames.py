"""Read-only cycle profiling attached to a repeatable Mesen controller route."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('rom', type=Path)
parser.add_argument('--name', default='performance')
parser.add_argument('--route', default='playthrough')
parser.add_argument('--detailed', action='store_true')
parser.add_argument('--actors', action='store_true')
args = parser.parse_args()
output = ROOT/'analysis'/f'{args.name}.csv'
sections = {}
bases = {'BANK0': 0xbb10, 'BANK5': 0x9e50, 'BANK6': 0xba40, 'FIXED': 0xe402}
wanted = ['ConvertWhipDrops', 'ItemInteractions',
          'StompEnemies', 'WhipUpdate', 'Fireballs', 'PlayerPalette']
segment = None
for line in (ROOT/'build/mario.lst').read_text().splitlines():
    match = re.search(r'\.segment "(\w+)"', line)
    if match:
        segment = match[1]
    match = re.match(r'([0-9A-F]+)r\s+\d+\s+(\w+):$', line)
    if match and match[2] in wanted:
        sections[match[2]] = bases[segment] + int(match[1], 16)
assert set(sections) == set(wanted)
lua = '''local frame=0
local current=nil
local section=nil
local sectionStart=0
local starts={}
local skipped=0
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function cycle() return emu.getState()['cpu.cycleCount'] end
local log=assert(io.open(FRAME_OUTPUT_PATH,'w'))
local actorLog=assert(io.open(ACTOR_OUTPUT_PATH,'w'))
actorLog:write('frame,actor,ai,pose,y,sprites,cycles\\n')
local actorStart=nil
emu.addMemoryCallback(function()
 if ACTORS and frame>=1800 and frame<2000 then
  local x=r(0x05)
  actorStart={frame,x,r(0x434+x),r(0x31c+x),r(0x354+x),r(r(0x08)+256*r(0x09)),cycle()}
 end
end,emu.callbackType.exec,0x80d6)
emu.addMemoryCallback(function()
 if actorStart then
  actorStart[7]=cycle()-actorStart[7]
  actorLog:write(table.concat(actorStart,',')..'\\n');actorLog:flush();actorStart=nil
 end
end,emu.callbackType.exec,0x80a8)
log:write('frame,stage,mode,world,power,health,whip,fireballs,cycles,skipped,logic,sprites,custom,actors,convert,candles,items,stomps,whipupdate,fireupdate,palette\\n')
local function beginSection(name)
 if not current or r(0x27)~=5 then return end
 local now=cycle()
 if section then current[section]=(current[section] or 0)+now-sectionStart end
 section=name;sectionStart=now
end
emu.addMemoryCallback(function()
 if r(0x1b)==0 then
  current={frame=frame,stage=r(0x28),mode=r(0x18),world=r(0x40)+256*r(0x41),power=r(0x6001),health=r(0x45),whip=r(0x603e),fireballs=r(0x6020)+r(0x6021),start=cycle()}
  skipped=0;section=nil
 else skipped=skipped+1 end
end,emu.callbackType.exec,0xc052)
local function start(name) if current then starts[name]=cycle() end end
local function finish(name) if current and starts[name] then current[name]=cycle()-starts[name];starts[name]=nil end end
emu.addMemoryCallback(function() start('logic') end,emu.callbackType.exec,0xc0a4)
emu.addMemoryCallback(function() finish('logic') end,emu.callbackType.exec,0xc0a7)
emu.addMemoryCallback(function() start('sprites') end,emu.callbackType.exec,0xc0ac)
emu.addMemoryCallback(function() finish('sprites') end,emu.callbackType.exec,0xc0af)
emu.addMemoryCallback(function() start('custom') end,emu.callbackType.exec,0xcf19)
emu.addMemoryCallback(function()
 if r(0x27)~=5 then return end
 finish('custom');start('actors')
 if current and section then current[section]=(current[section] or 0)+cycle()-sectionStart;section=nil end
end,emu.callbackType.exec,0xe8f0)
emu.addMemoryCallback(function()
 finish('actors')
 if current and section then current[section]=(current[section] or 0)+cycle()-sectionStart;section=nil end
end,emu.callbackType.exec,0xcf1c)
emu.addMemoryCallback(function()
 if not current then return end
 current.cycles=cycle()-current.start;current.skipped=skipped
 if current.frame>=700 then
  local values={}
  for _,key in ipairs({'frame','stage','mode','world','power','health','whip','fireballs','cycles','skipped','logic','sprites','custom','actors','convert','candles','items','stomps','whipupdate','fireupdate','palette'}) do values[#values+1]=current[key] or 0 end
  log:write(table.concat(values,',')..'\\n');log:flush()
 end
 current=nil;section=nil
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function() frame=frame+1 end,emu.eventType.endFrame)
'''
lua = lua.replace('FRAME_OUTPUT_PATH', '[=['+output.as_posix()+']=]')
lua = lua.replace('ACTOR_OUTPUT_PATH', '[=['+(ROOT/'analysis'/f'{args.name}-actors.csv').as_posix()+']=]')
lua = lua.replace('ACTORS', 'true' if args.actors else 'false')
names = ['convert', 'candles', 'items', 'stomps', 'whipupdate', 'fireupdate', 'palette']
for name, short in zip(wanted if args.detailed else [], names):
    lua += f"emu.addMemoryCallback(function() beginSection('{short}') end,emu.callbackType.exec,0x{sections[name]:x})\n"
lua += 'dofile([=['+(ROOT/f'tests/{args.route}.lua').as_posix()+']=])\n'
with tempfile.TemporaryDirectory(prefix='nes-profile-') as directory:
    script = Path(directory)/'profile.lua'
    script.write_text(lua)
    result = subprocess.run([sys.executable, str(ROOT/'tools/run_mesen.py'), str(script), str(args.rom)],
                            cwd=ROOT, text=True, capture_output=True, timeout=45)
(ROOT/'analysis'/f'{args.name}.log').write_text(result.stdout+result.stderr)
rows = [{key: int(value) for key, value in row.items()} for row in csv.DictReader(output.open())]
active = [row for row in rows if row['mode'] == 5]
summary = {'rom_sha256': hashlib.sha256(args.rom.read_bytes()).hexdigest(),
           'route': args.route, 'route_passed': result.returncode == 0,
           'active_updates': len(active), 'missed_vblanks': sum(row['skipped'] for row in active)}
for stage in sorted({row['stage'] for row in active}):
    group = [row for row in active if row['stage'] == stage]
    summary[f'stage_{stage}'] = {'updates': len(group), 'missed_vblanks': sum(row['skipped'] for row in group)}
    for key in ['cycles', 'logic', 'sprites', 'custom', 'actors']+(names if args.detailed else []):
        values = sorted(row[key] for row in group)
        summary[f'stage_{stage}'][key] = {'mean': round(sum(values)/len(values)), 'max': max(values), 'p95': values[int((len(values)-1)*.95)]}
(ROOT/'analysis'/f'{args.name}.json').write_text(json.dumps(summary, indent=2))
print(json.dumps(summary, indent=2))
if result.returncode:
    print(result.stdout+result.stderr)
raise SystemExit(result.returncode)
