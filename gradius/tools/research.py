from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
ROOT=Path(__file__).resolve().parents[1]
BASE=Path('C:/nes/Gradius (USA).nes')
def main():
 (ROOT/'build').mkdir(exist_ok=True)
 rom=BASE.read_bytes();cpu=MPU();cpu.memory[0x8000:]=rom[16:0x8010];cpu.memory.extend([0,0,0]);d=Disassembler(cpu)
 lines=[];pc=0x8000
 while pc<0x10000:
  n,s=d.instruction_at(pc);lines.append(f'{pc:04X}: '+bytes(cpu.memory[pc:pc+n]).hex(' ').upper().ljust(9)+' '+s);pc+=n
 (ROOT/'build/native.asm').write_text('\n'.join(lines))
if __name__=='__main__':main()
