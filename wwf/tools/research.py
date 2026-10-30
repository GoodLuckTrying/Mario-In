from pathlib import Path
from py65.disassembler import Disassembler
from py65.devices.mpu6502 import MPU
import sys
ROOT=Path(__file__).resolve().parents[1]
ROM=Path('C:/nes/WWF WrestleMania (USA).nes').read_bytes()[16:]
if len(sys.argv)>1:
 bank=int(sys.argv[1],0);start=int(sys.argv[2],0);end=int(sys.argv[3],0)
 p=MPU();p.memory[0x8000:]=ROM[bank*32768:(bank+1)*32768];ds=Disassembler(p);lines=[]
 while start<end:
  n,s=ds.instruction_at(start);lines.append(f'{start:04X}  '+bytes(p.memory[start:start+n]).hex(' ').ljust(9)+' '+s);start+=n
 print('\n'.join(lines))
else:
 print('vectors',[(b,ROM[(b+1)*32768-6:(b+1)*32768].hex())for b in range(4)])
 for b in range(4):
  p=ROM[b*32768:(b+1)*32768];runs=[];i=0
  while i<len(p):
   e=i+1
   while e<len(p) and p[e]==p[i]:e+=1
   if e-i>100:runs.append((hex(i+0x8000),e-i,hex(p[i])))
   i=e
  print('bank',b,runs)
