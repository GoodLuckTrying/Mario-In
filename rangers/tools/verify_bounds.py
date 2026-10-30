"""Check wrapped terrain-cache probes, including native left-edge scratch reuse."""
from pathlib import Path
import json
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]

def main():
 rom=(ROOT/'dist/Mario and Luigi in Rescue Rangers.nes').read_bytes()
 labels=json.loads((ROOT/'build/manifest.json').read_text())['labels']
 cpu=MPU()
 cpu.memory[0x6a00:0x8000]=rom[16+8*16384:16+8*16384+0x1600]
 cpu.memory[0xc000:]=rom[16+15*16384:16+16*16384]
 def call(addr):
  cpu.sp=0xfd;cpu.memory[0x1fe]=0xfe;cpu.memory[0x1ff]=0x5f;cpu.pc=addr
  for _ in range(10000):
   if cpu.pc==0x5fff:return
   cpu.step()
  raise AssertionError(hex(cpu.pc))
 cases=0
 for camera in [0,16,128,224,239]:
  cpu.memory[0xfa]=camera;cpu.memory[0xfb]=5
  cpu.memory[0x600:0x700]=[0x44]*256
  for delta in range(-32,273):
   y=5*240+camera+delta
   cpu.memory[0x6983]=16;cpu.memory[0x6984]=0
   cpu.memory[0x6985]=y%240;cpu.memory[0x6986]=y//240
   call(labels['Tile'])
   assert cpu.a==(4 if 0<=delta<240 else 0),(camera,delta,cpu.a)
   cases+=1
 # Native EB3B used to branch past its Y calculation for a negative X
 # page. F217 consequently reported stale bottom-row spikes at the corner.
 cpu.memory[0x600:0x700]=[0]*256
 cpu.memory[0x660:0x680]=[0x44]*32
 cpu.memory[0x6e0:0x700]=[0x44]*32
 for a,v in {0x400:0xd0,0x4f0:0,0x500:0,0x510:0,0x520:5,
             0xfa:0,0xfb:5,0x07:192,0x08:5}.items():cpu.memory[a]=v
 cpu.x=0;cpu.a=6;cpu.y=2
 call(0xf217)
 assert cpu.memory[0x10]==0,'Left-edge foot probe must not report stale bottom-row hazards'
 original=Path("C:/nes/Chip 'n Dale - Rescue Rangers (USA).nes").read_bytes()
 cpu.memory[0xc000:]=original[16+7*16384:16+8*16384]
 cpu.memory[0x07]=192;cpu.memory[0x08]=5
 cpu.x=0;cpu.a=6;cpu.y=2
 call(0xf217)
 assert cpu.memory[0x10]==4,'Regression fixture must reproduce the original phantom hazard'
 print(f'PASS {cases} viewport probes and native top-left phantom-hazard regression')

if __name__=='__main__':main()
