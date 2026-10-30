from pathlib import Path
import hashlib,json
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
ROOT=Path(__file__).resolve().parents[1]
BASE=Path("C:/nes/Chip 'n Dale - Rescue Rangers (USA).nes")
rom=BASE.read_bytes()
def main():
 b=ROOT/'build';b.mkdir(parents=True,exist_ok=True)
 print(len(rom),rom[:16].hex(),hashlib.sha256(rom).hexdigest())
 for bank in range(8):
  m=MPU();start=0xC000 if bank==7 else 0x8000
  m.memory[start:start+16384]=rom[16+bank*16384:16+(bank+1)*16384]
  d=Disassembler(m);pc=start;lines=[]
  while pc<start+16384:
   n,s=d.instruction_at(pc)
   lines.append(f'{pc:04X}: '+bytes(m.memory[pc:pc+n]).hex(' ').upper().ljust(9)+' '+s)
   pc+=n
  (b/f'bank{bank}.asm').write_text('\n'.join(lines))
if __name__=='__main__':main()
