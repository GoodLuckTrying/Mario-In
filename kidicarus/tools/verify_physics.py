"""Differentially execute the port and original SMB1 6502 instructions."""
from pathlib import Path
import json, re
from py65.devices.mpu6502 import MPU

ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'tests/smb-reference-symbols.json'

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

def main():
    labels=json.loads((ROOT/'build/manifest.json').read_text())['labels']
    listing=(ROOT/'build/mario.lst').read_text()
    # Non-exported labels are resolved from the assembly listing.
    def addr(name):
        return labels[name] if name in labels else 0x8000+int(re.search(r'^([0-9A-Fa-f]{6})r?\s+\d+\s+'+name+':',listing,re.M)[1],16)
    ref=symbols();original=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[16:0x8010]
    bank=(ROOT/'build/bank8.bin').read_bytes();base=Path('C:/nes/Kid Icarus (USA, Europe).nes').read_bytes()[16+7*16384:]
    failures=[];updates=0
    cases=[]
    for kind in ['walk','run','release','reverse','air-neutral','air-turn','jump-short','jump-full','duck-jump']:
        for direction in [-1,1]:
            for power in [0,1,2]:cases.append((kind,direction,power))
    for kind in ['swim-short','swim-full','swim-repress','climb-up','climb-down','climb-side']:
        for direction in [-1,1]:
            for power in [0,1,2]:cases.append((kind,direction,power))
    for kind,direction,power in cases:
        smb=MPU();port=MPU();smb.memory[0x8000:]=original
        port.memory[0x8000:0xc000]=bank;port.memory[0xc000:]=base
        load=labels['__BRIDGES_LOAD__']-0x8000
        port.memory[0x6100:0x6800]=bank[load:load+0x700]
        set_values(smb,{0x33:1 if direction>0 else 2,0x45:1 if direction>0 else 2,0x74e:1,0xe:8,0x754:int(power==0),0x490:3,0x86:64,0xce:144,0x70a:0x70})
        set_values(port,{0x6800:0x4d,0x6801:2,0x680b:1 if direction>0 else 2,0x680c:1 if direction>0 else 2,0x6814:1,0x6815:8,0x6804:power,0x723:64,0x720:168,0x681b:0x70,0x6820:0xff,0xa0:2,0x6837:2})
        if kind.startswith('swim'):
            set_values(smb,{0x704:1,0x74e:0,0x70a:0xA})
            set_values(port,{0x68B3:1,0x68B0:1,0x681B:0xA,0x6814:0})
        if kind.startswith('climb'):
            set_values(smb,{0x1d:3,0x490:0xff})
            set_values(port,{0x6805:3,0x68B3:2})
        floor=176
        def tile(c):
            c.a=0x40 if c.a>=floor else 0;c.memory[0x6823]=c.a;c.y=0;c.p=(c.p&~0x83)|(2 if c.a==0 else 0)
        traps={addr('TileAt'):tile,addr('NativeTerrainEffect'):lambda c:None}
        for tick in range(80):
            d=1 if direction>0 else 2
            held=d
            if kind in ('run','release','reverse','air-neutral','air-turn','duck-jump'):held|=0x40
            if kind=='release' and tick>=35:held=0
            if kind=='reverse' and tick>=35:held=(d^3)|0x40
            if kind.startswith('jump-'):held=0x80 if tick<(1 if kind=='jump-short' else 25) else 0
            if kind=='air-neutral':held=(0x80 if tick<35 else 0) if tick>=10 else held
            if kind=='air-turn' and tick>=10:held=0x80|(d^3)
            if kind=='duck-jump':held=0x84 if tick<25 else 0
            if kind.startswith('swim'):
                held=d|(0x80 if tick<(1 if kind=='swim-short' else 25) or (kind=='swim-repress' and 30<=tick<50) else 0)
            if kind.startswith('climb'):
                held=8 if kind=='climb-up' else 4 if kind=='climb-down' else d
            set_values(smb,{0xa:held&0xc0,0xb:held&0xc,0xc:held&3,0x6fc:held})
            if smb.memory[0x783]:smb.memory[0x783]-=1
            if smb.memory[0x782]:smb.memory[0x782]-=1
            if smb.memory[0x789]:smb.memory[0x789]-=1
            set_values(port,{0x16:held,0x18:held&~port.memory[0x6803]})
            run(smb,ref['PlayerMovementSubs'])
            run(port,labels['MarioUpdate'],traps)
            # Reference background integration is a flat floor. The port uses
            # its own collision code through the tile lookup boundary above.
            if not kind.startswith('climb') and smb.memory[0xce]>=144 and smb.memory[0x9f]<128:
                set_values(smb,{0xce:144,0x1d:0,0x9f:0,0x433:0,0x416:0})
            if smb.memory[0x57]:smb.memory[0x45]=2 if smb.memory[0x57]>=128 else 1
            pairs={'vx':(0x57,0x6806),'xforce':(0x705,0x6807),'abs':(0x700,0x6808),
                   'xfrac':(0x400,0x6816),'vy':(0x9f,0x6818),'vyfrac':(0x433,0x6819),
                   'yfrac':(0x416,0x6817),'state':(0x1d,0x6805),'facing':(0x33,0x680b),
                   'run':(0x703,0x6809),'timer':(0x783,0x680a),'fall':(0x70a,0x681b),'gravity':(0x709,0x681a)}
            diffs={k:[smb.memory[a],port.memory[b]] for k,(a,b) in pairs.items() if smb.memory[a]!=port.memory[b]}
            if ((smb.memory[0xce]+24)&255)!=port.memory[0x720]:diffs['y']=[smb.memory[0xce],port.memory[0x720]-24]
            # Terrain side bounds are excluded here; native Mesen tests cover
            # them. X coordinates may wrap during an 80-update flat run.
            if smb.memory[0x86]!=port.memory[0x723]:diffs['x']=[smb.memory[0x86],port.memory[0x723]]
            if diffs:
                failures.append({'case':[kind,direction,power],'tick':tick,'differences':diffs});break
            smb.memory[0xd]=held&0xc0;updates+=1
    report={'cases':len(cases),'matched_updates':updates,'failures':failures}
    (ROOT/'build/physics-results.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2)[:9000])
    raise SystemExit(bool(failures))

if __name__=='__main__':main()
