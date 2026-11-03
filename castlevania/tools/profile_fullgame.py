"""Read-only cycle section totals on the installed, verified controller route."""
from pathlib import Path
import json,re,subprocess,csv,statistics
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'analysis/physics-fix-2026-10-23'
prefix=r'''
local frame=0;local row=nil;local starts={}
local function r(a) return emu.read(a,emu.memType.nesDebug) end
local function cycle() return emu.getState()['cpu.cycleCount'] end
local file=assert(io.open(PROFILE_CSV,'w'))
file:write('frame,stage,power,health,cycles,player,custom,actors,sprites,background,music,missed\n')
local function begin(name) if row then starts[name]=cycle() end end
local function finish(name) if row and starts[name] then row[name]=(row[name] or 0)+cycle()-starts[name];starts[name]=nil end end
emu.addMemoryCallback(function()
 if r(0x1b)==0 then
  row={frame=frame,stage=r(0x28),power=r(0x6001),health=r(0x45),start=cycle(),missed=0};starts={}
 elseif row then row.missed=row.missed+1 end
end,emu.callbackType.exec,0xc052)
for _,s in ipairs({{'player',0x934c,0xcf02},{'custom',0xcf19,0xe8f0},
 {'actors',0xe8f0,0xcf1c},{'sprites',0xc0ac,0xc0af},{'background',0xc071,0xc074},{'music',0xc097,0xc09a}}) do
 emu.addMemoryCallback(function() begin(s[1]) end,emu.callbackType.exec,s[2])
 emu.addMemoryCallback(function() finish(s[1]) end,emu.callbackType.exec,s[3])
end
emu.addMemoryCallback(function()
 if not row then return end
 row.cycles=cycle()-row.start
 if r(0x18)==5 then
  local vals={}
  for _,k in ipairs({'frame','stage','power','health','cycles','player','custom','actors','sprites','background','music','missed'}) do vals[#vals+1]=row[k] or 0 end
  file:write(table.concat(vals,',')..'\n');file:flush()
 end
 row=nil;starts={}
end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function() frame=frame+1 end,emu.eventType.endFrame)
local stop=emu.stop
emu.stop=function(code) file:close();stop(code) end
'''.replace('PROFILE_CSV',json.dumps((OUT/'baseline-cycles.csv').as_posix()))
s=(ROOT/'analysis/fullgame/stage18-credits-fresh.lua').read_text()
s=re.sub(r'^OUTPUT=.*$', 'OUTPUT='+json.dumps((OUT/'baseline-profile').as_posix()),s,count=1,flags=re.MULTILINE)
script=OUT/'baseline-profile.lua';script.write_text(prefix+s)
r=subprocess.run(['C:/mesen2/Mesen.exe','--testRunner','--enableStdout','--timeout=240','--doNotSaveSettings',str(script),'C:/nes/Mario In/Mario in Castlevania.nes'],capture_output=True,text=True,timeout=255)
(OUT/'baseline-profile.log').write_text(r.stdout+r.stderr)
assert r.returncode==0,r.stdout[-1000:]+r.stderr[-1000:]
with (OUT/'baseline-cycles.csv').open() as f:rows=[{k:int(v) for k,v in r.items()} for r in csv.DictReader(f)]
report={}
for stage in sorted({r['stage'] for r in rows}):
 group=[r for r in rows if r['stage']==stage]
 report[stage]={'updates':len(group),'missed':sum(r['missed'] for r in group)}
 for k in ['cycles','player','custom','actors','sprites','background','music']:
  a=sorted(r[k] for r in group);report[stage][k]={'mean':round(statistics.mean(a)),'p95':a[int(.95*(len(a)-1))],'max':max(a)}
(OUT/'baseline-cycles.json').write_text(json.dumps(report,indent=2))
for stage in [1,10,12,14]:print(stage,report.get(stage))
