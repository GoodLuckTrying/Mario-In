from pathlib import Path
import sys
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
P=Path(__file__).resolve().parents[1]
NAME={'karnov':'Karnov (USA).nes','rygar':'Rygar (USA).nes'}[P.name]
raw=Path('C:/nes',NAME).read_bytes()[16:]
bank,start,end=[int(v,0)for v in sys.argv[1:]]
p=MPU();p.memory[start&0xe000:(start&0xe000)+8192]=raw[bank*8192:(bank+1)*8192];d=Disassembler(p)
while start<end:
 n,s=d.instruction_at(start);print(f'{start:04X} '+bytes(p.memory[start:start+n]).hex(' ').ljust(9)+' '+s);start+=n
