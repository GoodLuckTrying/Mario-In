"""Directed differential audit of installed Mario physics and original SMB.

Only the fixture environment is RAM seeded. The supplied ROMs are read-only;
normal player/terrain code executes in Mesen. Results do not claim a clear.
"""
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import argparse
from smb_reference import labels, SMB
from verify_physics import lua

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'analysis/physics-audit-2026-10-23'
ROM = Path('C:/nes/Mario In/Mario in Castlevania.nes')
FIELDS = ('x','xfrac','y','yfrac','state','xspeed','xforce','xabs','vhi','vlo',
          'gravity','fallforce','facing','moving','runflag','runtimer','crouch')


def cases():
    result = []
    for scene in ('flat','wall','upper-wall','step-up','step-down','gap','corner','roof'):
        for power in (0,1,2):
            for direction in (1,-1):
                for speed in (16,40):
                    jump = scene in ('corner','roof')
                    result.append(dict(name=f'{scene}, form {power}, direction {direction}, speed {speed}',
                        scene=scene, power=power, direction=direction, speed=direction*speed,
                        origin=80 if direction>0 else 160, kind='audit', held=25,
                        jump=jump, ticks=40, fraction=0))
    # Approach a wall at every alignment within one metatile; this exposes
    # early wall stops, one-pixel ejection and direction-dependent bounds.
    for direction in (1,-1):
        for offset in range(16):
            result.append(dict(name=f'wall alignment {offset}, direction {direction}',
                scene='wall', power=1, direction=direction, speed=direction*40,
                origin=80+offset if direction>0 else 160+offset,
                kind='audit', held=0, jump=False, ticks=24, fraction=127))
    # Landing at an edge while releasing/repressing A and retaining fractions.
    for direction in (1,-1):
        for y in (155,156,159):
            for fraction in (0,127,255):
                result.append(dict(name=f'landing y {y}, fraction {fraction}, direction {direction}',
                    scene='flat', power=1, direction=direction, speed=direction*24,
                    origin=80 if direction>0 else 160, kind='audit', held=0,
                    jump=False, ticks=16, fraction=fraction,
                    seed_state=2, seed_y=y, seed_vhi=4, seed_vlo=112,
                    seed_yfrac=fraction, seed_gravity=112))
    return result


def edge_cases():
    result=[]
    for power in (0,1,2):
        for direction in (1,-1):
            for fraction in (0,127,255):
                for speed in (16,24,40):
                    result.append(dict(name=f'last supported jump, form {power}, direction {direction}, fraction {fraction}, speed {speed}',
                        scene='edge',power=power,direction=direction,speed=direction*speed,
                        origin=108 if direction>0 else 100,kind='audit',held=25,
                        jump=True,ticks=40,fraction=fraction))
    return result


TERRAIN = r'''
local function solid(c,x,y)
 local floor=192
 if c.scene=='step-up' and ((c.direction>0 and x>=112) or (c.direction<0 and x<128)) then floor=176 end
 if c.scene=='step-down' and ((c.direction>0 and x>=112) or (c.direction<0 and x<128)) then floor=208 end
 if c.scene=='gap' and x>=112 and x<144 then floor=240 end
 if c.scene=='edge' and ((c.direction>0 and x>=112) or (c.direction<0 and x<112)) then floor=208 end
 if y>=floor then return true end
 if c.scene=='wall' and x>=112 and x<128 and y>=64 then return true end
 if c.scene=='upper-wall' and x>=112 and x<128 and y>=160 and y<176 then return true end
 if c.scene=='corner' and x>=112 and x<128 and y>=144 and y<160 then return true end
 if c.scene=='roof' and y>=128 and y<144 then return true end
 return false
end
local function terrain(c)
 if PHYSICS_SMB then
  for a=0x500,0x69f do w(a,0) end
  for page=0,1 do for x=0,15 do for y=48,208,16 do
   if solid(c,page*256+x*16,y) then w((page==0 and 0x500 or 0x5d0)+y-32+x,0x61) end
  end end end
 else
  for a=0x5a0,0x6ff do w(a,0) end
  local parity=r(0xfbd6)
  for page=0,1 do for x=0,255,8 do for y=48,216,8 do
   if solid(c,page*256+x,y) then
    local base=(page+parity)%2==0 and 0x5a0 or 0x650
    local address=base+y-48+math.floor(x/32)
    w(address,r(address)+2^((3-math.floor(x/8)%4)*2))
   end
  end end end
 end
end
'''


def fixture():
    source = (ROOT/'tests/physics-traces.lua').read_text()
    # A left-facing fixture close to world zero must use a local position;
    # a negative camera origin would wrap its page and invent a 256px delta.
    source = source.replace('case.origin and case.direction<0 and 128 or x+8',
                            'case.origin and case.direction<0 and math.min(128,x+8) or x+8')
    source = source.replace('case.origin and case.direction<0 and x-120 or 0',
                            'case.origin and case.direction<0 and math.max(0,x-120) or 0')
    start = source.index('local function terrain(case)')
    end = source.index('local function seed(case)', start)
    source = source[:start] + TERRAIN + source[end:]
    source = source.replace(' terrain(case)\nend', r'''
 if case.seed_state then
  if PHYSICS_SMB then
   w(0x1d,case.seed_state);w(0xce,case.seed_y);w(0x9f,case.seed_vhi)
   w(0x433,case.seed_vlo);w(0x416,case.seed_yfrac);w(0x709,case.seed_gravity)
  else
   w(0x6070,case.seed_state);w(0x46c,1);w(0x3f,case.seed_y+16);w(0x354,case.seed_y+16)
   w(0x6005,case.seed_vhi);w(0x6004,case.seed_vlo);w(0x6006,case.seed_yfrac);w(0x6009,case.seed_gravity)
   w(0x514,1)
  end
 end
 terrain(case)
end''', 1)
    source = source.replace(" if case.kind=='start-run'", " if case.kind=='audit' then joy[moving]=true;joy.b=true;joy.a=case.jump and t<case.held\n elseif case.kind=='start-run'", 1)
    source = source.replace('if tick==80 then', 'if tick==PHYSICS_CASES[number].ticks then')
    source = source.replace("output:write(number..','..tick..','..table.concat(values,',')..'\\n')",
                            "output:write(number..','..tick..','..table.concat(values,',')..'\\n');output:flush()")
    return source


def main():
    global OUT,ROM
    parser=argparse.ArgumentParser()
    parser.add_argument('--edges',action='store_true')
    parser.add_argument('--rom',type=Path,default=ROM)
    parser.add_argument('--output',type=Path,default=OUT)
    parser.add_argument('--reuse-reference',action='store_true')
    args=parser.parse_args()
    ROM=args.rom.resolve();OUT=args.output.resolve()
    if args.edges: OUT=OUT/'edges'
    OUT.mkdir(exist_ok=True,parents=True)
    all_cases = edge_cases() if args.edges else cases()
    (OUT/'cases.json').write_text(json.dumps(all_cases,indent=2))
    native = labels()
    code = SMB.read_bytes()[16:0x8010]
    call = bytes([0x20,native['PlayerBGCollision']&255,native['PlayerBGCollision']>>8])
    assert code.count(call)==1
    native_end=0x8000+code.index(call)+3
    hashes = {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROM,SMB)}
    fixture_sha=hashlib.sha256(fixture().encode()).hexdigest()
    for tag,rom in [('smb',SMB),('hybrid',ROM)]:
        receipt=OUT/'reference-receipt.json'
        if tag=='smb' and args.reuse_reference:
            saved=json.loads(receipt.read_text())
            assert saved==dict(rom_sha256=hashes[str(SMB)],fixture_sha256=fixture_sha,cases=all_cases,
                trace_sha256=hashlib.sha256((OUT/'smb.csv').read_bytes()).hexdigest())
            continue
        script=OUT/(tag+'.lua')
        script.write_text('PHYSICS_SMB='+str(tag=='smb').lower()+'\nPHYSICS_CASES='+lua(all_cases)+'\n'
            +f'PHYSICS_ENTRY={native["PlayerMovementSubs"] if tag=="smb" else 0x934c}\n'
            +f'PHYSICS_END={native_end if tag=="smb" else 0xcf02}\n'
            +'PHYSICS_OUTPUT='+lua((OUT/(tag+'.csv')).as_posix())+'\n'+fixture())
        print('Capturing '+tag+f': {len(all_cases)} directed fixtures',flush=True)
        result=subprocess.run([sys.executable,str(ROOT/'tools/run_mesen.py'),str(script),str(rom),'--timeout=300'],
                              capture_output=True,text=True,timeout=315)
        (OUT/(tag+'.log')).write_text(result.stdout+result.stderr)
        assert result.returncode==0,result.stdout[-2000:]+result.stderr[-2000:]
        if tag=='smb': receipt.write_text(json.dumps(dict(rom_sha256=hashes[str(SMB)],fixture_sha256=fixture_sha,
            cases=all_cases,trace_sha256=hashlib.sha256((OUT/'smb.csv').read_bytes()).hexdigest()),indent=2))
    data=[]
    for tag in ('smb','hybrid'):
        with (OUT/(tag+'.csv')).open() as f:
            data.append({(int(r['case']),int(r['tick'])):r for r in csv.DictReader(f)})
    reference,candidate=data
    expected={(i,t) for i,c in enumerate(all_cases,1) for t in range(1,c['ticks']+1)}
    assert reference.keys()==candidate.keys()==expected
    failures=[]
    excluded=[]
    compared=0
    for i,c in enumerate(all_cases,1):
        diffs=[]
        native_pit=False
        for t in range(1,c['ticks']+1):
            # Castlevania starts native pit death when the translated body
            # anchor reaches 224. SMB can continue below that playfield.
            # Keep the raw captures, but compare ordinary motion only before
            # this documented game-specific death boundary. The independent
            # top-and-pit fixture verifies the actual native death/respawn.
            if c['scene']=='gap' and int(reference[i,t]['y'])>=208:
                native_pit=True
            if native_pit:
                excluded.append([i,t]);continue
            compared+=1
            for field in FIELDS:
                a,b=reference[i,t][field],candidate[i,t][field]
                if a!=b: diffs.append(dict(tick=t,field=field,smb=int(a),hybrid=int(b)))
        if diffs: failures.append(dict(number=i,case=c['name'],scene=c['scene'],
            first_differences=diffs[:12],different_values=len(diffs)))
    for p,h in hashes.items(): assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h
    report=dict(rom_hashes=hashes,cases=len(all_cases),updates=len(expected),
                compared_updates=compared,native_pit_death_samples=excluded,
                native_pit_death_reason='Castlevania pit death begins at raw SMB Y >=208; death dispatch is verified separately',
                mismatching_cases=len(failures),findings=failures,
                evidence='Matched directed terrain with native player updates; RAM-seeded fixtures, not a controller clear')
    (OUT/'results.json').write_text(json.dumps(report,indent=2))
    print(f'{len(failures)} of {len(all_cases)} directed cases differ; {compared} ordinary movement updates compared, {len(excluded)} native pit-death samples retained separately.')
    for f in failures[:16]: print(f['case'],f['first_differences'][:3])
    assert not failures,'Ordinary movement diverges from SMB; see results.json'


if __name__=='__main__': main()
