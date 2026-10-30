from pathlib import Path
import argparse,hashlib,importlib.util,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT.parent
NAME='Mario in Kung Fu'
SHA='2275213352411a23df7428496ad03991348ddee3034ac6db83d2d16f0d1f8554'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
def main():
 p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');a=p.parse_args()
 old=Path('C:/nes/Kung Fu (Japan, USA) (En).nes').read_bytes()
 smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
 assert hashlib.sha256(old).hexdigest()==SHA
 assert hashlib.sha256(smb).hexdigest()==SMBSHA
 spec=importlib.util.spec_from_file_location('assets',BASE/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets);assets.ROOT=ROOT;assets.graphics(smb)
 frames=(ROOT/'build/mario-frames.chr').read_bytes()
 from melee_art import build as melee_frames,SMALL,BIG
 melee=melee_frames(frames)
 (ROOT/'build/extra-mask.bin').write_bytes(bytes(sum(1<<row for row in range(4) if any(melee.get(f,bytes(192))[128+row*16:144+row*16])) for f in range(35)))
 prg=bytearray(old[16:0x8010]);chr=bytearray(64*8192)
 tiles=[6,7,8,9,12,13,15,0xD6];extra=[0xD7,0xD8,0xE6,0xE7];fire=0xEF
 from native_art import audit
 native_art=audit(old)
 (ROOT/'build/native-art.json').write_text(json.dumps(native_art,indent=2))
 assert not set(tiles+extra+[fire])&set(native_art['used']),'Mario must not overwrite native actor art'
 banks=[]
 # CNROM bus conflicts AND the written value with the ROM byte. A stable
 # $FF byte permits every bank value, including unused values in the audio.
 bank_port=prg.find(b'\xff',0x6000)+0x8000
 assert bank_port>=0xE000
 for i in range(64):
  banks.append(bank_port)
 (ROOT/'build/banklo.bin').write_bytes(bytes(x&255 for x in banks))
 (ROOT/'build/bankhi.bin').write_bytes(bytes(x>>8 for x in banks))
 (ROOT/'src/generated.inc').write_text(f'BANK_CODE=${banks[63]:04X}\nBANK0=${banks[0]:04X}\nFIRE_TILE=${fire:02X}\n')
 stair_banks={31:0,32:1,33:12,34:13}
 stair_hud=[0x5b,0xbc,0xbd,0xfd,0xfe]
 for f in range(35):
  loc=f*8192;chr[loc:loc+8192]=old[0x8010:]
  pose=stair_banks.get(f,f)
  art=melee.get(pose,frames[min(pose,25)*128:(min(pose,25)+1)*128]+bytes(64))
  for n,t in enumerate(tiles+extra):chr[loc+t*16:loc+(t+1)*16]=art[n*16:(n+1)*16]
  chr[loc+fire*16:loc+(fire+1)*16]=smb[0x8010+0x64*16:0x8010+0x65*16]
  if f in stair_banks:
   for tile in stair_hud:chr[loc+tile*16:loc+(tile+1)*16]=old[0x9010+tile*16:0x9010+(tile+1)*16]
 # Story screens have additional hard-coded sprites (including tile $09)
 # outside the gameplay actor scripts. They need the full native bank.
 chr[35*8192:36*8192]=old[0x8010:]
 cc=BASE/'vendor/smb1base/tools/Windows/cc65/bin'
 subprocess.run([str(cc/'ca65.exe'),'src/mario.s','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
 subprocess.run([str(cc/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
 labels={m[1]:int(m[0],16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
 changes=[]
 def put(addr,data,expected=None):
  off=addr-0x8000
  if expected:assert prg[off:off+len(bytes.fromhex(expected))]==bytes.fromhex(expected),(hex(addr),expected)
  prg[off:off+len(data)]=data;changes.append({'address':addr,'length':len(data)})
 def hook(addr,label,expected,op=0x20):
  v=labels[label];put(addr,bytes([op,v&255,v>>8]),expected)
 put(0x8258,(ROOT/'build/boot.bin').read_bytes())
 hook(0x82E9,'DmaGate','A9 02 8D');put(0x82EC,b'\xEA\xEA','14 40')
 hook(0x835E,'FrameTail','AD 37 05',0x4C)
 hook(0x8466,'MenuGate','A5 36 D0',0x4C);put(0x8469,b'\xEA','07')
 hook(0x87D2,'MoveGate','20 96 A6')
 hook(0x882E,'AnimGate','20 26 A8')
 hook(0xA826,'NativeAnimGate','AD A6 04',0x4C)
 hook(0xB2D1,'NativeActorDrawGate','B5 80 F0',0x4C);put(0xB2D4,b'\xEA','76')
 hook(0x8B75,'StairSpriteBank','0A 85 63',0x4C)
 hook(0x85EF,'LifeGate','8D A6 04')
 hook(0xC462,'DamageGate','BD A0 04',0x4C)
 hook(0xC0B6,'HurtBox','A5 94 38',0x4C)
 hook(0xC67B,'MeleeTop','B9 0C BC')
 hook(0xC680,'MeleeBottom','B9 12 BC')
 hook(0x8E82,'BottomSplitGate','20 BD 8E')
 hook(0xAE01,'GripGate','B5 9F C9',0x4C);put(0xAE04,b'\xEA','01')
 put(0x8A04,b'\x50','18')
 # Thomas was a background character. Mario is entirely sprites, so omit
 # those pose scripts rather than writing blank tiles over the stage's floor.
 def b(addr):return old[16+addr-0x8000]
 empty=0x9052
 assert b(empty)==0
 for i in range(0x25,0x4F):
  put(0x8056+i,bytes([empty&255]))
  put(0x80A5+i,bytes([empty>>8]))
 chr[63*8192:]=(ROOT/'build/hack.bin').read_bytes()
 header=bytearray(old[:16]);header[5]=64;header[6]=0x31;header[8]=0x20;header[10]=7
 out=bytes(header+prg+chr)
 (ROOT/'dist'/f'{NAME}.nes').write_bytes(out)
 (ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
 report={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':{},'hooks':changes,'mario_tiles':tiles,'extra_tiles':extra,'melee_banks':{'small':SMALL,'big':BIG},'fire_tile':fire,'stair_banks':stair_banks,'stair_hud':stair_hud,'scene_bank':35,'mapper':'CNROM with WRAM'}
 for path in [ROOT/'build/manifest.json',ROOT/'dist/build-manifest.json']:path.write_text(json.dumps(report,indent=2))
 if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
 if a.install:
  receipt=ROOT/'dist/verification.json'
  verified=json.loads(receipt.read_text())
  assert verified['rom_sha256']==report['output_sha256'] and verified['passed'] and all(c['passed'] for c in verified['checks']),'Verify this exact build before installing'
  for ext in ['nes','ips']:
   source=ROOT/'dist'/f'{NAME}.{ext}';target=Path('C:/nes')/source.name
   if target.exists() and target.read_bytes()!=source.read_bytes():
    backup=target.with_name(target.stem+' - backup '+hashlib.sha256(target.read_bytes()).hexdigest()[:8]+target.suffix)
    if not backup.exists():backup.write_bytes(target.read_bytes())
   target.write_bytes(source.read_bytes())
  (Path('C:/nes')/f'{NAME} - Readme.txt').write_bytes((ROOT/'README.md').read_bytes())
  (Path('C:/nes')/f'{NAME} - verification.json').write_bytes(receipt.read_bytes())
 print('Built',NAME,report['output_sha256'])
if __name__=='__main__':main()
