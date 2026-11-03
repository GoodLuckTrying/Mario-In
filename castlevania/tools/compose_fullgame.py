"""Compose the exact controller-only ancestry of an unedited checkpoint."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'analysis/fullgame'
parser=argparse.ArgumentParser()
parser.add_argument('endpoint')
parser.add_argument('--rom',type=Path,default=Path('C:/nes/Mario In/Mario in Castlevania.nes'))
args=parser.parse_args()
chain=[]
name=args.endpoint
while name!='first-door':
    config=json.loads((folder/(name+'.config.json')).read_text())
    chain.append(name)
    name=Path(config['checkpoint']).stem
chain.append(name)
chain.reverse()
records=[]
death_segments=[]
was_dead=False
for segment in chain:
    meta=json.loads((folder/(segment+'.json')).read_text())
    assert not meta.get('failed'), 'A failed branch must be explicitly reviewed before adoption'
    rows=list(csv.DictReader((folder/(segment+'-input.csv')).open()))
    assert len(rows)==meta['input_frames']
    records.extend(int(row['mask']) for row in rows)
    trace=folder/(segment+'-trace.csv')
    if trace.exists():
        for row in csv.DictReader(trace.open()):
            dead=row.get('mode')=='6' or (row.get('health')=='0' and row.get('mode')=='5')
            if dead and not was_dead:
                death_segments.append(segment)
            was_dead=dead
path=folder/(args.endpoint+'-composed-input.csv')
with path.open('w',newline='') as out:
    writer=csv.writer(out);writer.writerow(['frame','mask'])
    writer.writerows(enumerate(records,1))
manifest={'endpoint':args.endpoint,'segments':chain,'input_frames':len(records),
          'rom_sha256':hashlib.sha256(args.rom.read_bytes()).hexdigest(),
          'ancestry_rom_sha256':sorted(set(json.loads((folder/(name+'.config.json')).read_text()).get('rom_sha256','unknown') for name in chain if name!='first-door')),
          'input_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'checkpoint_assisted':True,'fresh_boot_verified':False,'full_game_clear':False,
          'native_deaths':len(death_segments),'native_death_segments':death_segments}
(folder/(args.endpoint+'-route.json')).write_text(json.dumps(manifest,indent=2))
print(json.dumps(manifest,indent=2))
