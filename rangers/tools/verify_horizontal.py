from pathlib import Path
import json
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
rom=(ROOT/'dist/Mario and Luigi in Rescue Rangers.nes').read_bytes()
h=json.loads((ROOT/'build/manifest.json').read_text())['labels']
def run(cpu,pc):
 cpu.pc=pc;cpu.sp=0xfd;cpu.memory[0x1fe]=0xfe;cpu.memory[0x1ff]=0xff
 for _ in range(20000):
  if cpu.pc==0xffff:return
  cpu.step()
 raise AssertionError('Horizontal collision routine did not return')
def tile(mem,x,y,value):
 a=0x600+(x//256%2)*128+(y//32)*16+x%256//16
 mem[a]=(mem[a]&15)|(value<<4) if y%32>=16 else (mem[a]&0xf0)|value
checks=0
for p in range(2):
 for power in range(3):
  for wall in range(32,481,16):
   for left in [False,True]:
    for frac in [0,64,128,192]:
     for gap in [0,1,2,3,4,8]:
      c=MPU();c.memory[0x6a00:0x8000]=rom[16+8*16384:16+8*16384+0x1600];c.memory[0xc000:]=rom[16+15*16384:16+16*16384]
      m=c.memory;m[0x6980]=p;m[0x6904]=power;m[0x691e]=int(power>0);m[0xfb]=5
      m[0x0510+p]=180;m[0x0520+p]=5;m[0x0400+p]=0xd0
      for y in range(32,193,16):tile(m,wall,y,3)
      edge=wall+24 if left else wall-8
      start=edge+gap if left else edge-gap
      m[0x04f0+p]=start%256;m[0x0500+p]=start//256
      m[0x6906]=0xcc if left else 0x34;m[0x6916]=frac
      speed=-0x34 if left else 0x34;delta=(speed*16+frac)//256
      expected=max(edge,start+delta) if left else min(edge,start+delta)
      run(c,h['MoveX']);actual=m[0x04f0+p]+256*m[0x0500+p]
      assert actual==expected,(p,power,wall,left,frac,gap,actual,expected)
      if expected!=start+delta:assert m[0x6906]==0,'Collision must stop horizontal speed'
      checks+=1
print(f'PASS {checks} full-speed horizontal boundary cases, both controllers, forms, directions, pages and fractional steps')
