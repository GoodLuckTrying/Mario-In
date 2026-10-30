"""Compare every adapter against the original Kid Icarus 6502 lookup."""
from pathlib import Path
import json
from py65.devices.mpu6502 import MPU
from verify_physics import run

ROOT=Path(__file__).resolve().parents[1]
def main():
    labels=json.loads((ROOT/'build/manifest.json').read_text())['labels']
    rom=Path('C:/nes/Kid Icarus (USA, Europe).nes').read_bytes()[16:]
    bank=(ROOT/'build/bank8.bin').read_bytes()
    grid=[0,1,3,7,8,15,16,31,63,64,127,128,191,223,239,240,248,255]
    count=0
    for mode,nativebank in [(2,2),(3,5),(4,2),(6,3),(8,3)]:
        paths=sorted((ROOT/'build').glob(f'stage-{mode}-power-*-740.wram'))
        assert paths,f'Capture stage {mode} first with tests/stages.lua'
        wram=paths[-1].read_bytes();ram=paths[-1].with_suffix('.ram').read_bytes()
        ref=MPU();port=MPU()
        for cpu in [ref,port]:cpu.memory[:0x800]=ram;cpu.memory[0x6000:0x8000]=wram
        ref.memory[0x8000:0xc000]=rom[nativebank*16384:(nativebank+1)*16384]
        port.memory[0x8000:0xc000]=bank
        entry=ref.memory[0x7f13]+ref.memory[0x7f14]*256
        for page in [0,1,255]:
            for scroll in [0,15,16,127,223,238,239]:
                for cpu in [ref,port]:
                    cpu.memory[0x1a]=page;cpu.memory[0x1b]=page;cpu.memory[0xfd]=scroll;cpu.memory[0xfe]=scroll
                for y in grid:
                    for x in grid:
                        for cpu in [ref,port]:cpu.a=y;cpu.y=x;cpu.x=32
                        run(ref,entry);run(port,labels['FastTileAt'])
                        expected=(ref.a,ref.memory[0],ref.memory[1],ref.x,ref.y)
                        actual=(port.a,port.memory[0],port.memory[1],port.x,port.y)
                        assert actual==expected,(mode,page,scroll,x,y,expected,actual)
                        count+=1
        print(f'Native stage {mode} lookup matched')
    (ROOT/'build/terrain-results.json').write_text(json.dumps({'passed':True,'native_lookups':count,'stage_modes':[2,3,4,6,8]},indent=2))
    print(f'{count} original-ROM tile lookups matched')
if __name__=='__main__':main()
