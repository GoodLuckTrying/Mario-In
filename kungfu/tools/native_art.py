from pathlib import Path
from py65.devices.mpu6502 import MPU
import json

def audit(rom):
 # Actor pose scripts do not include the native projectile, hit-spark,
 # smoke, score, life and menu writers. Protect those tiles as well.
 used={0,1,2,3,4,5,0x0a,0x0b,0xdb,0xdc,0xe4,0xf0,0xf1,0xf2,
       0xf3,0xf4,0xf5,0xff,0xfd,0xfe,0x5b,0xbc,0xbd}
 cases=[]
 for kind,count in enumerate([10,13,8,11,7,11,8,23,5,6,8,8,1,1,1,1,1,1,1]):
  for pose in range(count):
   c=MPU();m=c.memory;m[0x8000:]=rom[16:0x8010]
   for a in range(0x600,0x800):m[a]=0xf8
   m[0x80]=1;m[0x87]=kind;m[0xb7]=pose;m[0xb0]=100;m[0x8e]=120;m[0x9f]=1
   m[0xc0]=0;m[0x4b]=0;m[0x4c]=0;m[0x4d]=0
   for i in range(7):m[0x3c2+i]=i
   c.sp=0xfd;m[0x1fe:0x200]=[0xfe,0x7f];c.pc=0xb2c8
   for _ in range(15000):
    if c.pc==0x7fff:break
    c.step()
   else:continue
   tiles=[]
   for start,length in [(0x600,m[0x4b]),(0x6d0,m[0x4c]),(0x730,m[0x4d])]:
    tiles.extend(m[start+i+1] for i in range(0,min(length,0xd0),4))
   used.update(tiles);cases.append({'kind':kind,'pose':pose,'tiles':tiles})
 return {'used':sorted(used),'cases':cases}

if __name__=='__main__':
 root=Path(__file__).resolve().parents[1]
 result=audit(Path('C:/nes/Kung Fu (Japan, USA) (En).nes').read_bytes())
 print('Native reachable actor tiles',len(result['used']),'free',[hex(t) for t in range(256) if t not in result['used']])
 (root/'build/native-art.json').write_text(json.dumps(result,indent=2))
