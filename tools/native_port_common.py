"""Small, deterministic helpers shared by the two source-backed native ports."""
from pathlib import Path
import hashlib, json, re, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
CC65 = ROOT / 'vendor/smb1base/tools/Windows/cc65/bin'
SMB = Path('C:/nes/Super Mario Bros. (World).nes')
SMB_SHA = '0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'

def sha(data): return hashlib.sha256(data).hexdigest()

def lz_pack(data, base=0x6000):
    """Literal runs and absolute backward copies, decoded once with rendering off."""
    out=bytearray(); literal=bytearray(); i=0
    def flush():
        if literal: out.append(len(literal));out.extend(literal);literal.clear()
    while i<len(data):
        best=0; at=0
        for j in range(i):
            n=0
            while n<130 and i+n<len(data) and data[j+n]==data[i+n]:n+=1
            if n>best:best=n;at=j
        if best>=4:
            flush();out.extend([0x80+best-3,(base+at)&255,(base+at)>>8]);i+=best
        else:
            literal.append(data[i]);i+=1
            if len(literal)==127:flush()
    flush();out.append(0)
    return bytes(out)

def ips(old, new):
    out = bytearray(b'PATCH'); i = 0
    while i < len(new):
        if i < len(old) and old[i] == new[i]: i += 1; continue
        start = i; i += 1
        while i < len(new) and i-start < 65535:
            if i < len(old) and new[i:i+8] == old[i:i+8]: break
            i += 1
        out += start.to_bytes(3,'big') + (i-start).to_bytes(2,'big') + new[start:i]
    return bytes(out+b'EOF')

def labels(path):
    return {name:int(addr,16) for addr,name in re.findall(r'al ([\da-fA-F]+) \.(\w+)',path.read_text())}

def assemble(project):
    subprocess.run([str(CC65/'ca65.exe'),'-g','-I','src','-I',str(ROOT/'src'),
        'src/mario.s','-o','build/mario.o','-l','build/mario.lst'],cwd=project,check=True)
    subprocess.run([str(CC65/'ld65.exe'),'-C','src/hack.cfg','build/mario.o',
        '-Ln','build/labels.txt','-m','build/map.txt'],cwd=project,check=True)
    return labels(project/'build/labels.txt')

def mario_atlas(project, available, selected=None, extra=None):
    data = SMB.read_bytes(); assert sha(data)==SMB_SHA
    # Use the same audited SMB1 frames as the established platforming ports.
    sys.path.insert(0,str(ROOT/'tools'))
    from build import graphics
    art_dir=project/'build/source-art'
    graphics(data,output_dir=art_dir)
    frames = (art_dir/'mario-frames.chr').read_bytes()
    # walk 0/1/2, idle, jump, skid, duck, climb 0/1, small equivalents, death.
    selected = selected or [0,1,2,24,4,3,10,8,9,12,13,14,23,16,15,18,19,20,22,5,6,7]
    pool = iter(available); unique = {}; packed = {}; tables = []
    cells=[frames[n*128:n*128+128] for n in selected]
    for pixels in extra or []:
        frame=bytearray()
        for cy in range(4):
            for cx in range(2):
                for plane in range(2):
                    for y in range(8):
                        frame.append(sum(((pixels[cy*8+y][cx*8+x]>>plane)&1)<<(7-x) for x in range(8)))
        cells.append(frame)
    for frame in cells:
        row=[]
        for i in range(8):
            tile=bytes(frame[i*16:i*16+16])
            if tile not in unique:
                idx=next(pool); unique[tile]=idx; packed[idx]=tile
            row.append(unique[tile])
        tables += row
    # Sprite-only fireballs; the rest of each host's CHR remains untouched.
    fire=[]
    for t in (0x64,0x65):
        tile=data[0x8010+t*16:0x8010+(t+1)*16]
        idx=next(pool); packed[idx]=tile;fire.append(idx)
    text='MarioTiles:\n'+'\n'.join(' .byte '+','.join(f'${v:02X}' for v in tables[i:i+8]) for i in range(0,len(tables),8))
    text+='\nFireTiles: .byte '+','.join(f'${i:02X}' for i in fire)+'\n'
    (project/'src/art.inc').write_text(text)
    return packed

class Patcher:
    def __init__(self, base, fixed): self.rom=bytearray(base);self.fixed=fixed;self.changes=[]
    def put(self, bank, address, data, name, expected=None):
        offset=16+bank*16384+address-(0xc000 if bank==self.fixed else 0x8000)
        if expected is not None:
            expected=bytes.fromhex(expected) if isinstance(expected,str) else expected
            assert self.rom[offset:offset+len(expected)]==expected,(name,bank,hex(address),self.rom[offset:offset+len(expected)].hex())
        self.rom[offset:offset+len(data)] = data
        self.changes.append(dict(bank=bank,cpu=address,size=len(data),name=name))
    def hook(self, bank, address, target, name, expected, jsr=False):
        self.put(bank,address,bytes([0x20 if jsr else 0x4c,target&255,target>>8]),name,expected)

def install(project, name):
    for suffix in ('nes','ips'):
        source=project/'dist'/f'{name}.{suffix}'; dest=Path('C:/nes')/source.name
        data=source.read_bytes()
        if dest.exists() and dest.read_bytes()!=data:
            backup=dest.with_name(dest.stem+' - backup '+sha(dest.read_bytes())[:8]+dest.suffix)
            if not backup.exists(): backup.write_bytes(dest.read_bytes())
        dest.write_bytes(data);assert dest.read_bytes()==data
