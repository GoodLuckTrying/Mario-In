"""Build a native MMC1 ROM and IPS patch from the user's local originals."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess

ROOT = Path(__file__).resolve().parents[1]
CC65 = ROOT.parent / 'vendor/smb1base/tools/Windows/cc65/bin'
KI = Path('C:/nes/Kid Icarus (USA, Europe).nes')
SMB = Path('C:/nes/Super Mario Bros. (World).nes')
HASHES = ['931786d6920dea7f9e183d907d3c4cff123197fcd14ae4066f1e817df32fd02f',
          '0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea']

def ips(old, new):
    out=bytearray(b'PATCH');i=0
    while i<len(new):
        if i<len(old) and old[i]==new[i]: i+=1;continue
        start=i;i+=1
        while i<len(new) and i-start<65535:
            if i<len(old) and old[i]==new[i] and new[i:i+8]==old[i:i+8]:break
            i+=1
        out+=start.to_bytes(3,'big')+(i-start).to_bytes(2,'big')+new[start:i]
    return out+b'EOF'

def graphics(smb, output_dir=None):
    output_dir = output_dir or ROOT/'build'
    output_dir.mkdir(parents=True, exist_ok=True)
    chr=smb[0x8010:]
    # Original SMB1 PlayerGraphicsTable, in its original row order.
    frames=[list(range(i,i+8)) for i in (0,8,16,24,32)]
    frames += [[8,9,40,41,42,43,44,45],[8,9,10,11,12,48,44,45],
               [8,9,10,11,46,47,44,45],[8,9,40,41,42,43,92,93],
               [8,9,10,11,12,13,94,95],[252,252,8,9,88,89,90,90],
               [8,9,40,41,42,43,14,15]]
    frames += [[252]*4+x for x in [[50,51,52,53],[54,55,56,57],
        [58,55,59,60],[61,62,63,64],[50,65,66,67],
        [50,51,68,69],[50,51,68,71],[50,51,72,73],
        [50,51,144,145],[58,55,146,147],[158,158,159,159],
        [58,55,79,79]]]
    frames += [[0,1,76,77,74,74,75,75]]
    frames += [[252,252,0,1,76,77,78,78]]
    packed=bytearray()
    for n,frame in enumerate(frames):
        for index,tile in enumerate(frame):
            data=chr[tile*16:tile*16+16]
            # SMB mirrors the right half of repeated standing/duck/death tiles.
            if (n==10 and index==7) or (n==22 and index in (5,7)) or (n==23 and index==7) or (n==24 and index in (5,7)) or (n==25 and index==7):
                data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
            packed+=data
    (output_dir/'mario-frames.chr').write_bytes(packed)
    assets=[]
    # SMB mushroom, flower, star, green mushroom, then rotating fireballs.
    for kind,tiles in enumerate([(0x76,0x77,0x78,0x79),(0xD6,0xD6,0xD9,0xD9),
                  (0x8D,0x8D,0xE4,0xE4),(0x76,0x77,0x78,0x79),
                  (0x64,0x65,0x64,0x65)]):
        for index,t in enumerate(tiles):
            data=chr[t*16:t*16+16]
            if kind in (1,2) and index%2:data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
            assets+=data
    for index,tile in enumerate((0x3A,0x37,0x4F,0x4F)):
        data=chr[tile*16:tile*16+16]
        if index==3:data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
        assets+=data
    (output_dir/'items.chr').write_bytes(bytes(assets))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
    originals=[p.read_bytes() for p in (KI,SMB)]
    for p,data,sha in zip((KI,SMB),originals,HASHES):
        if hashlib.sha256(data).hexdigest()!=sha:raise SystemExit(f'Unexpected base ROM: {p}')
    (ROOT/'build').mkdir(exist_ok=True);(ROOT/'dist').mkdir(exist_ok=True)
    graphics(originals[1])
    subprocess.run([str(CC65/'ca65.exe'),'src/mario.s','-I','src','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
    subprocess.run([str(CC65/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
    labels={m[1]:int(m[0],16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
    old=originals[0];rom=bytearray(old[:16]+old[16:]+b'\xff'*(8*16384))
    rom[4]=16
    rom[16+15*16384:]=old[16+7*16384:]
    bank=(ROOT/'build/bank8.bin').read_bytes();rom[16+8*16384:16+9*16384]=bank
    changes=[]
    def put(addr,data,name,expected=None):
        offset=16+15*16384+addr-0xc000
        if expected is not None:
            expected=bytes.fromhex(expected)
            assert bytes(rom[offset:offset+len(expected)])==expected,(name,hex(addr))
        rom[offset:offset+len(data)]=data;changes.append({'name':name,'cpu':hex(addr),'bytes':len(data)})
    def hook(addr,label,op=0x4c,expected=None):
        a=labels[label];put(addr,bytes([op,a&255,a>>8]),label,expected)
    def bank_put(bank,addr,data,name,expected):
        offset=16+bank*16384+addr-0x8000
        assert bytes(rom[offset:offset+len(bytes.fromhex(expected))])==bytes.fromhex(expected),(name,bank,hex(addr))
        rom[offset:offset+len(data)]=data
        changes.append({'name':name,'bank':bank,'cpu':hex(addr),'bytes':len(data)})
    def bank_hook(bank,addr,label,expected):
        a=labels[label];bank_put(bank,addr,bytes([0x4c,a&255,a>>8]),label,expected)
    put(0xCD9E,(ROOT/'build/boot.bin').read_bytes(),'Bootstrap in replaced Pit friction routine')
    hook(0xC024,'Bootstrap',0x20,expected='20 07 EB')
    hook(0xCFA9,'UpdateBridge',expected='20 A8 CF')
    hook(0xC4CD,'RenderBridge',expected='10 03 4C')
    hook(0xEB2E,'DmaBridge',expected='A9 00 8D')
    hook(0xEE42,'FastPalette',expected='A9 3F 8D')
    hook(0xC14D,'AssetsBridge',expected='A9 10 4C')
    hook(0xD4A2,'FireBridge',expected='AD 2F 01')
    hook(0xDA09,'ContactBridge',expected='A5 A2 30')
    hook(0xD990,'HitBridge',expected='A5 3C D0')
    hook(0xD9BC,'HitAltBridge',expected='A5 3C D0')
    hook(0xEF01,'VideoEnableBridge',expected='AD 00 01')
    hook(0xDDCC,'PickupBridge',expected='85 08 20')
    hook(0xCD8F,'DeathBridge',expected='EA EA EA')
    hook(0xC3E0,'PaletteBridge',expected='AD 52 01')
    hook(0xC0A0,'LifeBridge',expected='A5 A0 85')
    hook(0xCC5C,'DyingBridge',expected='BD 05 07')
    hook(0xDA69,'DamageBridge',expected='A5 A6 D0')
    hook(0xCD02,'ScrollBridge',expected='4C 0C 7F')
    hook(0xC3BF,'StageResetBridge',expected='A9 90 9D')
    bank_hook(2,0x946A,'VerticalStream','A5 FD C5')
    bank_hook(2,0xAB71,'HorizontalStream','A5 FE 29')
    bank_hook(3,0x9701,'VerticalStream','A5 FD C5')
    bank_hook(5,0x909D,'HammerHudBridge','AD 4F 01')
    bank_hook(5,0x8FB9,'FortressStatsBridge','A5 3A C9')
    bank_hook(5,0x8BAE,'FortressMapBridge','A5 68 0A')
    for bank,addr in [(2,0x8145),(2,0x9AD9),(3,0x8146),(3,0x9D82),(5,0x811C)]:
        a=labels['RoomVideoBridge']
        bank_put(bank,addr,bytes([0x20,a&255,a>>8])+b'\xEA'*7,
                 'Share room text/palette and shop-price bank visit',
                 'A9 0A 20 90 CA A9 0C 20 90 CA')
    bank_put(2,0x80FB,b'\xEA'*6,'Prepare vertical rows after camera movement','20 6D 95 20 3E 96')
    bank_put(2,0x9AA0,b'\xEA'*6,'Prepare horizontal columns after camera movement','20 7B AC 20 2A AD')
    bank_put(3,0x80FC,b'\xEA'*6,'Prepare Skyworld rows after camera movement','20 04 98 20 D5 98')
    # B is run/fire. The original bow and melee attack dispatcher is removed.
    put(0xCF48,b'\x60','Disable Pit bow charge')
    put(0xEC81,b'\x60','Keep Mario out of Pit hammer control mode')
    # RenderBridge must be able to enter the stock renderer after its JMP hook.
    # $C4D2 remains the original non-special metasprite renderer.
    (ROOT/'dist/Mario in Kid Icarus.nes').write_bytes(rom)
    (ROOT/'dist/Mario in Kid Icarus.ips').write_bytes(ips(old,rom))
    info={'base_rom':str(KI),'base_sha256':HASHES[0],'smb_rom':str(SMB),'smb_sha256':HASHES[1],
          'output_sha256':hashlib.sha256(rom).hexdigest(),'mapper':1,'prg_kib':256,
          'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT.parent/'vendor/smb1base',text=True).strip(),
          'hooks':changes,'labels':labels}
    (ROOT/'build/manifest.json').write_text(json.dumps(info,indent=2))
    if args.install:
        for ext in ('nes','ips'):
            dest=Path('C:/nes')/f'Mario in Kid Icarus.{ext}'
            data=(ROOT/f'dist/Mario in Kid Icarus.{ext}').read_bytes()
            if dest.exists() and dest.read_bytes()!=data:
                backup=dest.with_name(dest.stem+' - backup '+hashlib.sha256(dest.read_bytes()).hexdigest()[:8]+dest.suffix)
                if not backup.exists():backup.write_bytes(dest.read_bytes())
            dest.write_bytes(data)
    print('Built',len(rom),'bytes;',info['output_sha256'])

if __name__=='__main__':main()
