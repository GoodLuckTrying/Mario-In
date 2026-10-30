"""Build a reproducible native NES patch from the user's local ROMs."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CV = Path('C:/nes/Castlevania (USA) (Rev 1).nes')
SMB = Path('C:/nes/Super Mario Bros. (World).nes')
EXPECTED = {
    CV: '5e859d77bc0e3a9f30a7c14d2637b9c2aae6ce19f6520a7c9b252a86974f7800',
    SMB: '0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea',
}

def wsl_path(path):
    p = str(path.resolve()).replace('\\', '/')
    return '/mnt/' + p[0].lower() + p[2:]

def assemble():
    (ROOT/'build').mkdir(exist_ok=True)
    subprocess.run([str(ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin/ca65.exe'), 'src/mario.s', '-I', 'src', '-o', 'build/mario.o', '-l', 'build/mario.lst'], cwd=ROOT, check=True)
    subprocess.run([str(ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin/ld65.exe'), '-C', 'src/hack.cfg', 'build/mario.o', '-Ln', 'build/hack.lbl', '-m', 'build/hack.map'], cwd=ROOT, check=True)
    return {m[1]: int(m[0], 16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)', (ROOT/'build/hack.lbl').read_text())}

def generate_custom_chr():
    # Arrange SMB's original 8x8 tiles as Castlevania's 8x16 sprites.
    smb=SMB.read_bytes()
    chr_data=smb[16+32768:]
    pairs=[(0x32,0x34),(0x33,0x35),(0x36,0x38),(0x37,0x39),(0x3A,0x3B),(0x37,0x3C),
           (0x3A,0x4F),(0x37,0x4F),(0x32,0x42),(0x41,0x43),
           (0,2),(1,3),(4,6),(5,7),(8,10),(9,11),(12,14),(13,15),
           (16,18),(17,19),(20,22),(21,23),(0,0x4C),(1,0x4D),(0x4A,0x4B),(0x4A,0x4B),
           (0x20,0x22),(0x21,0x23),(0x24,0x26),(0x25,0x27),
           (0x64,0xFC),(0x65,0xFC),(0x76,0x78),(0x77,0x79),(0xD6,0xD9),(0x60,0x60)]
    tiles=[]
    for index,(a,b) in enumerate(pairs):
        upper=chr_data[a*16:a*16+16]
        lower=chr_data[b*16:b*16+16]
        # SMB mirrors repeated standing tiles on the right side.
        if index==7:
            lower=bytes(int(f'{v:08b}'[::-1],2) for v in lower)
        if index==25:
            upper=bytes(int(f'{v:08b}'[::-1],2) for v in upper)
            lower=bytes(int(f'{v:08b}'[::-1],2) for v in lower)
        if index==35:
            # A jumping coin is two halves of one tile, vertically reflected.
            lower=lower[:8][::-1]+lower[8:][::-1]
        tiles.append(upper+lower)
    # Heart pickup uses the original Castlevania 8x16 heart art.
    original_chr=CV.read_bytes()[0x5018:0x7018]
    tiles[35]=original_chr[0x1000+0x9e*16:0x1000+0xa0*16]
    # Compress the original 16x32 candelabra into one 8x16 sprite.
    cv_chr=CV.read_bytes()[0x5018:0x7018]
    def tile_pixels(tile):
        data=cv_chr[0x1000+(tile&0xfe)*16:0x1000+(tile&0xfe)*16+32]
        rows=[]
        for row in range(16):
            base=(row//8)*16; y=row%8
            rows.append([((data[base+y]>>(7-x))&1)|(((data[base+y+8]>>(7-x))&1)<<1) for x in range(8)])
        return rows
    for flame in (0x97,0x99):
        full=tile_pixels(flame)+tile_pixels(0x9b)
        full=[row+row[::-1] for row in full]
        small=[[full[y*2][x*2] for x in range(8)] for y in range(16)]
        packed=bytearray()
        for half in range(2):
            for plane in range(2):
                for y in range(8):
                    packed.append(sum(((small[half*8+y][x]>>plane)&1)<<(7-x) for x in range(8)))
        tiles.append(bytes(packed))
    for a,b in [(0x3D,0x3F),(0x3E,0x40),(0x18,0x1A),(0x19,0x1B),(0x1C,0x1E),(0x1D,0x1F)]:
        tiles.append(chr_data[a*16:a*16+16]+chr_data[b*16:b*16+16])
    dead=chr_data[0x9E*16:0xA0*16]
    tiles.extend([dead,bytes(int(f'{v:08b}'[::-1],2) for v in dead)])
    # Retain native art in the reserved slots; its old locations now hold Mario.
    # Slots $60/$62 are unused by all four custom whip poses. Reuse them for meat
    # pickup rather than overwriting another native sprite beyond this range.
    for tile in [0x1E,0x20,0x64,0x66,0x2E,0x30,0x46,0x48,0x58,0x56,0x6C,0x6A]:
        tiles.append(cv_chr[tile*16:tile*16+32])
    # Original SMB crouch: visible rows 08/09, 58/59, and mirrored 5A feet.
    for a,b in [(0x08,0x58),(0x09,0x59),(0x5A,0xFC)]:
        tiles.append(chr_data[a*16:a*16+16]+chr_data[b*16:b*16+16])
    mario_chr=b''.join(tiles)
    return mario_chr

def main():
    for path, sha in EXPECTED.items():
        if hashlib.sha256(path.read_bytes()).hexdigest() != sha:
            raise SystemExit(f'Unexpected ROM revision: {path}')
    (ROOT/'build').mkdir(exist_ok=True)
    (ROOT/'build/custom-sprites.chr').write_bytes(generate_custom_chr())
    from native_graphics import sprite_remap, metasprites
    mapping = sprite_remap(CV.read_bytes())
    destinations = b''.join((0x1000+(tile & 0xfe)*16).to_bytes(2,'little') for tile in mapping.values())
    (ROOT/'build/native-chr-dest.bin').write_bytes(destinations)
    labels = assemble()
    rom = bytearray(CV.read_bytes())
    patches = []
    def put(offset, data, name, expected=None):
        before = bytes(rom[offset:offset+len(data)])
        if expected is not None and before != expected:
            raise ValueError(f'{name}: unexpected bytes at {offset:X}: {before.hex()}')
        rom[offset:offset+len(data)] = data
        patches.append({'name': name, 'file_offset': offset, 'length': len(data), 'before_sha256': hashlib.sha256(before).hexdigest()})
    def hook(prg_offset, opcode, label, expected):
        a = labels[label]
        put(prg_offset+16, bytes([opcode,a&255,a>>8]), label, bytes.fromhex(expected))
    put(6, bytes([0x51,0x08,0]), 'MMC5 separate background and sprite CHR banks', bytes.fromhex('21 08 20'))
    put(10, bytes([7,8]), '8KB work RAM and 16KB CHR RAM', bytes.fromhex('00 07'))
    put(0x1C1D8+16, bytes.fromhex('48 98 0a 09 80 8d 15 51 ea ea 68 60'), 'MMC5 native 16KB PRG switching', bytes.fromhex('48 b9 00 c0 99 00 c0 99 00 c0 68 60'))
    for pose in metasprites(CV.read_bytes()):
        for record in pose:
            tile=record['tile']
            if tile in mapping and rom[record['tile_offset']] == tile:
                put(record['tile_offset'], bytes([mapping[tile]]), 'preserve native sprite tile reference', bytes([tile]))
    # Holy-water icons write OAM directly rather than using a metasprite.
    for offset, tile in [(0x1A155,0x52),(0x1A156,0x54)]:
        put(offset+16,bytes([mapping[tile]]),'preserve direct native subweapon HUD sprite',bytes([tile]))
    put(0x1FF2A+16, (ROOT/'build/bridges.bin').read_bytes(), 'MMC5 reset and graphics bridges', b'\xff'*(ROOT/'build/bridges.bin').stat().st_size)
    put(0x1FFFC+16, labels['MapperReset'].to_bytes(2,'little'), 'MMC5 reset vector', bytes.fromhex('08 c0'))
    put(0x1FFFE+16, labels['HudIrq'].to_bytes(2,'little'), 'MMC5 HUD IRQ vector', bytes.fromhex('bf c0'))
    data=(ROOT/'build/hudirq.bin').read_bytes()
    assert len(data)<=0x4B
    put(0x1F8C7+16,data,'interrupt-driven HUD split replaces raster polling',CV.read_bytes()[0x1F8C7+16:0x1F8C7+16+len(data)])
    hook(0x1C03C,0x4C,'MainLoopIrq','4c 30 c0')
    for offset in (0x1C08D,0x1C0CE):
        hook(offset,0x20,'FinishHudSetup','20 1f c1')
    hook(0x1FD77,0x20,'FarRefreshChr','20 d4 c1')
    for offset in [0x1B7EA,0x1B84F,0x1B87C,0x1B928,0x1B989,0x1C69C,0x1C7FC,0x1C830,0x1C83A,0x1C947]:
        hook(offset,0x20,'PrepareNativeChr','20 23 fd')
    for name, offset in [('bank0',0x3B10),('bank5',0x15E50),('bank6',0x1BA40)]:
        data=(ROOT/f'build/{name}.bin').read_bytes()
        put(offset+16, data, name, b'\xff'*len(data))
    data=(ROOT/'build/fixed.bin').read_bytes()
    # E402..E469 is the disabled Simon whip collision routine and its private
    # scalar bounds tables. No remaining native routine reads those tables.
    assert len(data) <= 0x68
    put(0x1E402+16,data,'fixed bridges in disabled whip collision code')
    data=(ROOT/'build/aibridge.bin').read_bytes()
    assert len(data)<=0x26
    put(0x1E737+16,data,'bank-safe native AI returns in displaced health handler',CV.read_bytes()[0x1E737+16:0x1E737+16+len(data)])
    hook(0x1E94F,0x4C,'PrepareActorBank','ad c9 e9')
    for offset in (0x1C39B,0x1C4EA,0x18693):
        hook(offset,0x20,'FarScriptedAi','20 f0 e8')
    # SMB preserves both direction bits; the original Simon filter forced Right.
    put(0x1CED0+16,bytes.fromhex('4c e0 ce'),'SMB simultaneous-direction input',bytes.fromhex('a5 f7 29'))
    hook(0x1934C,0x4C,'MarioUpdate','a5 47 f0')
    hook(0x1CEFD,0x20,'AfterMarioUpdate','a0 04 20')
    put(0x1CF00+16,bytes([0xEA,0xEA]),'post-player bank switch padding',bytes.fromhex('d6 c1'))
    hook(0x19407,0x20,'JumpStart','20 98 99')
    hook(0x1948E,0x20,'AirDirection','20 79 94')
    hook(0x194C7,0x20,'VerticalMove','20 1e 9b')
    hook(0x19F3C,0x20,'SideOffset','b1 00 85')
    hook(0x19ECE,0x4C,'DeferredSideCheck','ad 6c 04')
    hook(0x19E70,0x4C,'DeferredFootCheck','a5 3f 38')
    put(0x19F3F+16,bytes([0xEA]),'side offset hook padding',bytes([0x4B]))
    hook(0x194FC,0x20,'LandingReset','20 f8 9a')
    put(0x19E7F+16,bytes([5]),'SMB left foot probe at sprite-left +3',bytes([4]))
    # Replace the disabled whip's wall gate and hitbox with queued fireball
    # terrain contacts. Keep the native wall data and destruction/drop path.
    hook(0x1A828,0x4C,'FireballWalls','ad 34 04')
    hook(0x1A898,0x20,'FireballBrickCollision','a5 41 85')
    put(0x1A89B+16,bytes.fromhex('4c c9 a8'),'return fireball wall overlap to native handler',bytes.fromhex('03 a5 70'))
    hook(0x1C393,0x20,'DoorUpdate','20 6a fa')
    hook(0x19869,0x4C,'RightScrollBoundary','a4 4b 88')
    hook(0x1989A,0x20,'MoveCentered','20 ab 98')
    hook(0x198CB,0x4C,'RightLocalBound','c9 f0 f0')
    put(0x198CE+16,bytes([0xEA]),'right bound padding',bytes([0x3B]))
    hook(0x198E9,0x4C,'LeftLocalBound','c9 08 f0')
    put(0x198EC+16,bytes([0xEA]),'left bound padding',bytes([0x1D]))
    # Native streaming assumes Simon moves <=1 pixel/frame. SMB running can
    # cross a 32-pixel column before its six strips have loaded at half rate.
    put(0x1F633+16,bytes([0xEA,0xEA]),'advance streaming strips each frame',bytes.fromhex('d0 0a'))
    put(0x1F687+16,bytes([0xEA,0xEA]),'load streaming strips each frame',bytes.fromhex('d0 03'))
    # The native segment sentinel already deduplicates spawning. Checking it
    # every scrolling frame also catches skipped 64-pixel boundaries.
    data=(ROOT/'build/scrollbridge.bin').read_bytes()
    assert len(data) == 0x1B
    put(0x1F5EA+16,data,'scroll spawn bridge with exact world placement',bytes.fromhex('a6 3c ca f0 03 ca d0 1c a5 2e 29 3f d0 0d a5 18 c9 08 f0 07 c9 0c f0 03 20 96 d1'))
    put(0x19450+16,bytes.fromhex('4c 58 94'),'SMB crouch keeps normal movement and jump dispatch',bytes.fromhex('a9 03 8d'))
    hook(0x1AD4F,0x4C,'SetNativeSpeed','a9 00 85')
    hook(0x1AC70,0x4C,'PlatformCheck','a9 1a 85')
    hook(0x1AD00,0x4C,'PlatformContact','ad 84 05')
    hook(0x86,0x4C,'SelectPlayerSprite','bd 1c 03')
    hook(0x72,0x4C,'FastSpriteSetup','bd 38 03')
    # Indexed lookup reproduces the original sprite allocation/clear order.
    oam = labels['NextOamIndex']
    for offset, resume in [(0xB5, 0x80BE), (0x122, 0x812B)]:
        put(offset+16, bytes([0xBD,oam&255,oam>>8,0xAA,0x4C,resume&255,resume>>8]),
            'fast native OAM permutation', bytes.fromhex('8a 18 69 c4 c9 44 90'))
    hook(0x12B,0x4C,'SpriteBudgetNext','c6 07 c8')
    hook(0x1C98A,0x20,'ResetMario','a9 40 85')
    put(0x1C98D+16,bytes([0xEA]),'health reset hook padding',bytes([0x44]))
    hook(0x1CF19,0x20,'FarInteractions','20 f0 e8')
    hook(0x1E3FF,0x4C,'CollisionSetup','ad 34 04')
    hook(0x1E703,0x20,'GetPlayerCollisionY','ad 54 03')
    put(0x1E6F0+16,bytes.fromhex('65 5e'),'SMB player horizontal combat radius',bytes.fromhex('69 04'))
    hook(0x1E734,0x4C,'MarioDamage','20 96 fe')
    hook(0x1E9E6,0x4C,'ActorEnd','bd 34 04')
    for offset in (0x154F4,0x15520):
        hook(offset,0x20,'DraculaCooldown','20 a7 ee')
    hook(0x1E38C,0x20,'DraculaHeadCooldown','ad 8f 04')
    # Replace Simon's movement-locking attack action. The custom whip shares
    # B with running/fireballs and renders without using their actor slots.
    hook(0x19A2A,0x4C,'SubweaponAction','ad 34 04')
    put(0x1CDEB+16,bytes.fromhex('0f 16 27 18'),'Mario palette',bytes.fromhex('0f 27 37 07'))
    for offset in (0x1CD05,0x1CD23):
        put(offset+16,bytes.fromhex('40 62'),'native sprite palette retains Mario form',bytes.fromhex('e9 cd'))
    output=ROOT/'build/Mario in Castlevania.nes'
    output.write_bytes(rom)
    # IPS stores only changed records, never the original ROM.
    source=CV.read_bytes()
    ips=bytearray(b'PATCH')
    i=0
    while i<len(rom):
        if rom[i]==source[i]:
            i+=1
            continue
        start=i
        while i<len(rom) and rom[i]!=source[i] and i-start<65535:
            i+=1
        data=rom[start:i]
        ips+=start.to_bytes(3,'big')+len(data).to_bytes(2,'big')+data
    ips+=b'EOF'
    (ROOT/'build/Mario in Castlevania.ips').write_bytes(ips)
    (ROOT/'build/patch-manifest.json').write_text(json.dumps({'input_sha256':EXPECTED[CV],'output_sha256':hashlib.sha256(rom).hexdigest(),'labels':labels,'patches':patches,'native_sprite_remap':mapping},indent=2))
    (ROOT/'build/Mario in Castlevania - Controls.txt').write_bytes((ROOT/'src/controls.txt').read_bytes())
    print(f'Built {output}; {len(rom)} bytes; {len(ips)} byte IPS patch')
    print('Segments:', {n:(ROOT/f'build/{n}.bin').stat().st_size for n in ['bank0','bank5','bank6','fixed','scrollbridge']})

if __name__=='__main__':
    main()
