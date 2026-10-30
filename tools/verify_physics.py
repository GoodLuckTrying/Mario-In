"""Differentially execute the port and original SMB1 6502 instructions."""
from pathlib import Path
import json, re
from py65.devices.mpu6502 import MPU

ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'kidicarus/tests/smb-reference-symbols.json'

def symbols():
    return json.loads(REFERENCE.read_text())['labels']

def run(cpu,addr,traps={}):
    cpu.sp=0xfd;cpu.memory[0x1fe]=0xfe;cpu.memory[0x1ff]=0x7f;cpu.pc=addr
    for _ in range(20000):
        if cpu.pc==0x7fff:return
        if cpu.pc in traps:
            traps[cpu.pc](cpu);cpu.pc=0x6f00;cpu.memory[0x6f00]=0x60
        cpu.step()
    raise AssertionError(f'6502 call did not return: {cpu.pc:04X}')

def set_values(cpu,values):
    for addr,value in values.items():cpu.memory[addr]=value&255
