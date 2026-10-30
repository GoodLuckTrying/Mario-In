"""Compare fireball free flight to SMB1's actual gravity and movement code."""
from pathlib import Path
import json
from py65.devices.mpu6502 import MPU
from verify_physics import run,symbols,set_values
ROOT=Path(__file__).resolve().parents[1]
def main():
    labels=json.loads((ROOT/'build/manifest.json').read_text())['labels'];ref=symbols()
    original=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[16:0x8010]
    bank=(ROOT/'build/bank8.bin').read_bytes();updates=0
    for direction in [-1,1]:
        smb=MPU();port=MPU();smb.memory[0x8000:]=original;port.memory[0x8000:0xc000]=bank
        load=labels['__BRIDGES_LOAD__']-0x8000;port.memory[0x6100:0x6800]=bank[load:load+0x700]
        set_values(smb,{0x5e:direction*64,0xa6:4,0x8d:128,0xd5:128})
        set_values(port,{0x738:128,0x739:0x8c if direction>0 else 0x84,0x73b:128,0x6858:4,0x6860:100})
        def empty(c):c.a=0;c.memory[0x6823]=0;c.y=0;c.p=(c.p&~0x81)|2
        for tick in range(30):
            smb.x=7;smb.a=0;smb.memory[0]=0x50;smb.memory[2]=3;run(smb,ref['ImposeGravity'])
            smb.x=7;run(smb,ref['MoveObjectHorizontally'])
            port.x=0x38;port.y=0;run(port,labels['FireOne'],{labels['TileAt']:empty})
            expected=[smb.memory[a] for a in [0x8d,0xd5,0xa6,0x43a,0x41d]]
            actual=[port.memory[a] for a in [0x73b,0x738,0x6858,0x6850,0x6862]]
            assert actual==expected,(direction,tick,expected,actual)
            updates+=1
    (ROOT/'build/fireball-results.json').write_text(json.dumps({'passed':True,'matched_updates':updates,'directions':2},indent=2))
    print(f'{updates} fireball updates match original SMB1 instructions')
if __name__=='__main__':main()
