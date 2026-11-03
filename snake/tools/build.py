from pathlib import Path
import sys
import argparse,hashlib,importlib.util,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT.parent
sys.path.insert(0, str(ROOT.parent / 'tools'))
from port_paths import ensure_install_dir
NAME='Mario and Luigi in Snake Rattle n Roll'
SHA='4e456a9b3872631f9937f2e14747022fe7a91a9dd9b4773ab326715411cc73a9'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
def main():
 p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');a=p.parse_args()
 old=Path('C:/nes/Snake Rattle n Roll (USA).nes').read_bytes();smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
 assert hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(smb).hexdigest()==SMBSHA
 spec=importlib.util.spec_from_file_location('assets',BASE/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets);assets.ROOT=ROOT;assets.graphics(smb)
 prg=bytearray(old[16:0x8010])
 from directional import build as make_directional
 atlas_info=make_directional(old,smb)
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
 put(0x8251,(ROOT/'build/boot.bin').read_bytes())
 hook(0x96F8,'PlayerGate','BD 77 05',0x4C)
 hook(0x8CCF,'InputGate','20 79 D2')
 hook(0x9B1F,'EatGate','20 54 9D')
 hook(0xCCD7,'ManholeLookup','A0 FE C8',0x4C)
 hook(0xFE60,'DrawGate','B9 AF 04',0x4C)
 hook(0xDF55,'GravityGate','85 04 BC',0x4C);put(0xDF58,b'\xEA\xEA','9B 04')
 hook(0x9C38,'JumpGate','20 86 95')
 hook(0xBCE5,'StompGate','20 84 95')
 hook(0xBD77,'DamageGate','A6 0B BD',0x4C);put(0xBD7A,b'\xEA\xEA','9F 05')
 # Only death callers reset Mario, not the shared bonus-room continuation.
 hook(0x9817,'RespawnGate','20 06 BE')
 hook(0x9833,'RespawnGate','20 06 BE')
 hook(0x8D03,'SceneGate','20 8B 91')
 hook(0xFC1B,'FireDraw','4C 6E 81',0x4C)
 hook(0xFAF8,'NativeActorGate','B9 9B 04',0x4C)
 hook(0xFBB9,'ShadowGate','B9 9B 04',0x4C)
 put(0xFBFE,b'\x02','01')
 hook(0x8452,'SetupAtlas','85 E2 A2',0x4C);put(0x8455,b'\xEA','0F')
 # Verified native scene-render call; no generated research listing is needed.
 hook(0x8D5D,'DrawScene','20 31 FA')
 hook(0xFFC9,'LoadSprite','8D FF BF',0x4C)
 hook(0xFFDD,'LoadBackground','8D FF DF',0x4C)
 for address in [0x8C1C,0x8C9D,0x8CCC,0xFF74]:hook(address,'DisplayBank','20 C9 FF')
 hook(0xFF97,'DmaGate','A9 02 8D');put(0xFF9A,b'\xEA\xEA','14 40')
 extra=bytearray(b'\xFF'*32768)
 extra[0x251:0x295]=prg[0x251:0x295]
 extra[0x1000:0x2000]=(ROOT/'build/hack.bin').read_bytes()
 extra[0x3000:0x5000]=(ROOT/'build/upload.bin').read_bytes()
 extra[0x7FB5:]=old[16+0x7FB5:0x8010]
 art=bytearray(b'\xFF'*32768)
 packets=(ROOT/'build/directional-packets.chr').read_bytes();art[:len(packets)]=packets
 art[0x5000:0x7000]=(ROOT/'build/frame-copy.bin').read_bytes()
 art[0x7F61:]=prg[0x7F61:]
 # A pose copy may span vblank. Its bank-safe NMI runs native terrain /
 # music work on time and restores this asset bank before resuming.
 art[0x7FFA:0x7FFC]=labels['CopyNmi'].to_bytes(2,'little')
 # Every mapper-selectable 32K bank has a valid native reset vector.
 extra[0x7F61:]=prg[0x7F61:]
 header=bytearray(old[:16]);header[4]=8;header[5]=0;header[8]=0;header[10]=7;header[11]=10
 out=bytes(header+prg+extra+old[0x8010:]+art)
 (ROOT/'dist'/f'{NAME}.nes').write_bytes(out);(ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
 report={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':{},'hooks':changes,'atlas':atlas_info,'prg_bytes':131072,'chr_ram_bytes':65536,'mapper':'MMC1 with WRAM and double-buffered CHR RAM'}
 for path in [ROOT/'build/manifest.json',ROOT/'dist/build-manifest.json']:path.write_text(json.dumps(report,indent=2))
 if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
 if a.install:
  receipt=ROOT/'dist/verification.json'
  verified=json.loads(receipt.read_text())
  assert verified['rom_sha256']==report['output_sha256'] and verified['passed'] and all(c['passed'] for c in verified['checks']),'Verify this exact build before installing'
  for ext in ['nes','ips']:
   source=ROOT/'dist'/f'{NAME}.{ext}';target=ensure_install_dir()/source.name
   if target.exists() and target.read_bytes()!=source.read_bytes():
    backup=target.with_name(target.stem+' - backup '+hashlib.sha256(target.read_bytes()).hexdigest()[:8]+target.suffix)
    if not backup.exists():backup.write_bytes(target.read_bytes())
   target.write_bytes(source.read_bytes())
  (ensure_install_dir()/f'{NAME} - Readme.txt').write_bytes((ROOT/'README.md').read_bytes())
  (ensure_install_dir()/f'{NAME} - verification.json').write_bytes(receipt.read_bytes())
 print('Built',NAME,report['output_sha256'])
if __name__=='__main__':main()
