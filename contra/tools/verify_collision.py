from pathlib import Path
import json,random
from py65.devices.mpu6502 import MPU
root=Path(__file__).resolve().parents[1];m=json.loads((root/'build/manifest.json').read_text());rom=(root/'dist/Mario and Luigi in Contra.nes').read_bytes();n=m['native'];h=m['labels']
mem=[0]*65536;mem[0x8000:0xC000]=rom[16+8*16384:16+9*16384];mem[0xC000:]=rom[16+15*16384:]
rng=random.Random(1234)
for a in range(n['BG_COLLISION_DATA'],n['BG_COLLISION_DATA']+128):mem[a]=rng.randrange(256)
cpu=MPU(memory=mem)
def run(pc,a,y):
 cpu.pc=pc;cpu.a=a;cpu.y=y;cpu.x=13;cpu.sp=0xFD;cpu.p=0x20;mem[0x1FE]=0xFF;mem[0x1FF]=0x7F
 for i in range(500):
  cpu.step()
  if cpu.pc==0x8000:return cpu.a
 raise Exception(hex(cpu.pc))
count=0
for hs,vs in [(0,0),(15,7),(127,224),(255,239),(200,50)]:
 mem[n['HORIZONTAL_SCROLL']]=hs;mem[n['VERTICAL_SCROLL']]=vs
 for nt in range(2):
  mem[n['PPUCTRL_SETTINGS']]=0xB0|nt
  for x,y in [(rng.randrange(256),rng.randrange(256))for _ in range(1000)]:
   expected=run(n['get_bg_collision'],x,y)
   for label in ['P0Tile','P1Tile']:
    actual=run(h[label],y,x)
    assert actual==expected,(label,hs,vs,nt,x,y,actual,expected)
    assert cpu.x==13
    count+=1
print('PASS',count,'native collision probes, both controllers, scroll and nametable wrap')
