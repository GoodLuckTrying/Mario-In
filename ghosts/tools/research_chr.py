from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
sys.path.insert(0,'tools');from audit_all_physics import execute
p=Path('ghosts');h=json.load(open(p/'build/manifest.json'))['labels'];r=(p/'dist/Mario in Ghosts n Goblins.nes').read_bytes();base=Path("C:/nes/Ghosts'n Goblins (USA).nes").read_bytes()
alltiles=set();owners={}
for frame in range(0x40,256):
 m=MPU();m.memory[0x8000:0xc000]=base[16+4*16384:16+5*16384];m.memory[0xc000:]=base[-16384:]
 for a,v in {0x29:0x80,0x2a:4,0x2b:0,0x2c:2,0x480:100,0x481:frame,0x482:0,0x483:100,0x484:255,0x485:255,0x486:255,0x487:255}.items():m.memory[a]=v
 try:execute(m,0x80d0)
 except AssertionError:continue
 end=m.memory[0x2b]+256*m.memory[0x2c]
 for a in range(0x201,min(end,0x400),4):
  t=m.memory[a];alltiles.add(t);owners.setdefault(t,set()).add(frame)
print('Overlap',[(hex(t),[hex(x) for x in sorted(owners[t])]) for t in sorted(alltiles & set(list(range(0x10,0x20))+[0x30,0x31]))])
print('unused',','.join(hex(t)for t in range(256) if t not in alltiles))
