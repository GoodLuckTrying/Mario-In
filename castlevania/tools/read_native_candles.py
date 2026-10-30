"""Read the unchanged fixed-bank authored candle records for route planning."""
import argparse
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('stage',type=int)
parser.add_argument('room',type=int)
args=parser.parse_args()
prg=Path('C:/nes/Mario in Castlevania.nes').read_bytes()[16:]
def read(address):
    assert 0xC000<=address<=0xFFFF
    return prg[0x10000+address]
def word(address):
    return read(address)+256*read(address+1)
table=word(0xD290+args.stage*2)
records=word(table+args.room*2)
pages=read(0xFBB0+args.stage)
pages=(pages&15) if args.room else pages>>4
for column in range((pages+1)*4):
    index=read(records+column*2+1)
    entry=word(0xD6C6+index*2)
    if not read(entry):
        continue
    reward=0
    if read(entry)==255:
        reward=read(entry+1)
        entry+=2
    if read(entry)==254:
        entry+=1
    print(f'world={column*64+read(entry):4} y={read(entry+1):3} reward={reward:2} column={column:2}')
