"""Compare fall-wait permission with the actual native level-scroll queries."""
from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from verify_physics import run,set_values

def main():
 p=ROOT/'karnov';manifest=json.loads((p/'build/manifest.json').read_text());h=manifest['labels']
 rom=(p/'dist/Mario in Karnov.nes').read_bytes()[16:];cases=0
 memory=[0]*65536
 memory[0x6000:0x8000]=rom[16*8192:17*8192]
 memory[0xa000:0xc000]=rom[12*8192:13*8192]
 memory[0xc000:]=rom[30*8192:32*8192]
 for stage in range(9):
  memory[0x8000:0xa000]=rom[stage*8192:(stage+1)*8192]
  for row in [0,1,11,12,13,23,24,35,36]:
   for column in [0,1,15,16,64,128,143]:
    native=MPU(memory=memory.copy());set_values(native,{0x9f:column,0xa0:row})
    run(native,0xb19f);available=native.a!=0
    for lock in [0,0x20]:
     for scroll in [0,0x50,0xb0,0x90]:
      c=MPU(memory=memory.copy());set_values(c,{0x9f:column,0xa0:row,0x5d:lock,0xc4:scroll})
      run(c,h['CanScrollDown'])
      expected=scroll==0x90 or(available and lock==0)
      assert bool(c.p&1)==expected,(stage,row,column,lock,scroll,'native permission mismatch')
      cases+=1
 report=dict(rom_sha256=manifest['output_sha256'],passed=True,cases=cases,scope='Actual native B19F level bounds/map queries, native B124 down-scroll lock, and an already valid in-progress downward strip.')
 (p/'build/fall-boundary-results.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS',cases,'native fall/camera permission cases')
if __name__=='__main__':main()
