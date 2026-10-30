"""Compare full normal-land SMB position, subpixel and momentum traces."""
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from smb_reference import labels, SMB

ROOT=Path(__file__).resolve().parents[1]
ROM=ROOT/'build/Mario in Castlevania.nes'
cases=[]
for speed in (0,8,9,15,16,24,25,27,28,40):
    for held in (1,8,25):
        cases.append(dict(name=f'jump speed {speed}, A {held}',speed=speed,held=held,kind='jump',power=0))
for power in (0,1,2):
    for direction in (-1,1):
        for kind in ('run-reverse','walk-reverse','air-turn','re-jump','ledge'):
            cases.append(dict(name=f'{kind}, form {power}, direction {direction}',speed=direction*24,held=25,kind=kind,power=power))
for fraction in (1,127,128,255):
    cases.append(dict(name=f'camera crossing fraction {fraction}',speed=40,held=0,kind='run-reverse',power=0,fraction=fraction))
for power in (0,1,2):
    for roof in (128,144):
        for speed in (0,25):
            cases.append(dict(name=f'ceiling {roof}, form {power}, speed {speed}',speed=speed,held=25,kind='jump',power=power,roof=roof))

for power in (1,2):
    for direction in (-1,1):
        for speed in (24,40):
            for kind in ('duck-slide','duck-jump','duck-release'):
                cases.append(dict(name=f'{kind}, form {power}, speed {direction*speed}',speed=direction*speed,held=25,kind=kind,power=power))

for power in (0,1,2):
    for direction in (-1,1):
        for kind in ('start-run','start-walk','release-run','neutral-brake','simultaneous','air-neutral','repress-jump','down-direction','up-down','crouch-ceiling'):
            speed=0 if kind.startswith('start-') else direction*40
            cases.append(dict(name=f'{kind}, form {power}, direction {direction}',speed=speed,held=25,kind=kind,power=power,direction=direction,origin=224 if direction<0 else 80,roof=144 if kind=='crouch-ceiling' else None))


def lua(value):
    if isinstance(value,dict): return '{'+','.join(f'{key}={lua(item)}' for key,item in value.items())+'}'
    if value is None: return 'nil'
    if isinstance(value,list): return '{'+','.join(map(lua,value))+'}'
    return json.dumps(value)

def reference_receipt():
    return {'reference_sha256':hashlib.sha256(SMB.read_bytes()).hexdigest(),
            'fixture_sha256':hashlib.sha256((ROOT/'tests/physics-traces.lua').read_bytes()).hexdigest(),
            'cases':cases,
            'trace_sha256':hashlib.sha256((ROOT/'analysis/physics-smb.csv').read_bytes()).hexdigest()}


def main(reuse_reference=False, candidate_prefix_cases=0):
    prefix=[]
    if candidate_prefix_cases:
        receipt=json.loads((ROOT/'analysis/physics-candidate-prefix.json').read_text())
        assert receipt['candidate_sha256']==hashlib.sha256(ROM.read_bytes()).hexdigest()
        assert receipt['fixture_sha256']==hashlib.sha256((ROOT/'tests/physics-traces.lua').read_bytes()).hexdigest()
        assert receipt['cases']==cases
        trace=ROOT/'analysis/physics-hybrid.csv'
        assert receipt['trace_sha256']==hashlib.sha256(trace.read_bytes()).hexdigest()
        with trace.open() as f:
            prefix=[row for row in csv.DictReader(f) if row.get('crouch') is not None and int(row['case'])<=candidate_prefix_cases]
        assert {(int(row['case']),int(row['tick'])) for row in prefix}=={(n,t) for n in range(1,candidate_prefix_cases+1) for t in range(1,81)}
    native=labels()
    code=SMB.read_bytes()[16:0x8010]
    call=bytes([0x20,native['PlayerBGCollision']&255,native['PlayerBGCollision']>>8])
    assert code.count(call)==1
    native_end=0x8000+code.index(call)+3
    with tempfile.TemporaryDirectory(prefix='smb-physics-') as directory:
        directory=Path(directory)
        for tag,rom in [('smb',SMB),('hybrid',ROM)]:
            if tag=='smb' and reuse_reference:
                # A completed reference capture can be reused only when its
                # ROM, terrain/input fixtures, cases and trace are identical.
                receipt=json.loads((ROOT/'analysis/physics-reference-capture.json').read_text())
                assert receipt==reference_receipt(), 'Reference fixtures changed; rerun both engines'
                continue
            first=candidate_prefix_cases if tag=='hybrid' else 0
            output=directory/f'{tag}-continuation.csv' if first else ROOT/f'analysis/physics-{tag}.csv'
            script=directory/f'{tag}.lua'
            script.write_text('PHYSICS_SMB='+str(tag=='smb').lower()+'\nPHYSICS_CASES='+lua(cases[first:])+'\n'
                              +f'PHYSICS_ENTRY={native["PlayerMovementSubs"] if tag=="smb" else 0x934c}\n'
                              +f'PHYSICS_END={native_end if tag=="smb" else 0xcf02}\n'
                              +'PHYSICS_OUTPUT=[=['+output.as_posix()+']=]\n'
                              +'dofile([=['+(ROOT/'tests/physics-traces.lua').as_posix()+']=])\n')
            result=subprocess.run([sys.executable,str(ROOT/'tools/run_mesen.py'),str(script),str(rom),'--timeout=240'],text=True,capture_output=True,timeout=255)
            (ROOT/f'analysis/verification/physics-{tag}.log').write_text(result.stdout+result.stderr)
            assert result.returncode==0,result.stdout+result.stderr
            if first:
                with output.open() as f:
                    reader=csv.DictReader(f);columns=reader.fieldnames
                    continuation=list(reader)
                assert len(continuation)==80*(len(cases)-first)
                for row in continuation: row['case']=str(int(row['case'])+first)
                with (ROOT/'analysis/physics-hybrid.csv').open('w',newline='') as f:
                    writer=csv.DictWriter(f,fieldnames=columns);writer.writeheader();writer.writerows(prefix+continuation)

            if tag=='smb':
                (ROOT/'analysis/physics-reference-capture.json').write_text(json.dumps(reference_receipt(),indent=2))
    def rows(tag):
        with (ROOT/f'analysis/physics-{tag}.csv').open() as file:
            return {(int(row['case']),int(row['tick'])):row for row in csv.DictReader(file)}
    original,candidate=rows('smb'),rows('hybrid')
    assert original.keys()==candidate.keys(),'Every physics update must be captured'
    failures=[]
    fields=('x','xfrac','y','yfrac','state','xspeed','xforce','xabs','vhi','vlo','gravity','fallforce','facing','moving','runflag','runtimer','crouch')
    for number,case in enumerate(cases,1):
        diffs=[]
        for tick in range(1,81):
            for field in fields:
                if original[number,tick][field]!=candidate[number,tick][field]:
                    diffs.append(dict(tick=tick,field=field,smb=original[number,tick][field],hybrid=candidate[number,tick][field]))
        if diffs: failures.append(dict(case=case['name'],number=number,first_differences=diffs[:8],different_values=len(diffs)))
    report={'candidate_sha256':hashlib.sha256(ROM.read_bytes()).hexdigest(),'reference_sha256':hashlib.sha256(SMB.read_bytes()).hexdigest(),
            'passed':not failures,'cases':len(cases),'updates':len(original),'fields':fields,'failures':failures,
            'evidence_type':'Actual SMB/Castlevania engine updates on matched controlled terrain with translated sprite anchors',
            'fixture_environment':'Original SMB level timer is refreshed between cases to isolate movement from time-up deaths',
            'reference_capture_reused':reuse_reference,
            'candidate_capture_batches':[[1,candidate_prefix_cases],[candidate_prefix_cases+1,len(cases)]] if candidate_prefix_cases else [[1,len(cases)]],
            'limitations':['Castlevania stairs, doors, health and enemy interactions retain their authored integration']}
    (ROOT/'analysis/physics-results.json').write_text(json.dumps(report,indent=2))
    for failure in failures[:15]: print(failure['case']+': '+str(failure['first_differences'][:3]))
    assert not failures, f'{len(failures)} physics cases differ; see analysis/physics-results.json'
    print(f'All {len(cases)} cases / {len(original)} full position and subpixel updates match original SMB.')

if __name__=='__main__': main()
