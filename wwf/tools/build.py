from pathlib import Path
import sys
import argparse,hashlib,importlib.util,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT.parent
sys.path.insert(0, str(ROOT.parent / 'tools'))
from port_paths import ensure_install_dir
NAME='Mario and Luigi in WWF WrestleMania'
ORIGINAL=Path('C:/nes/WWF WrestleMania (USA).nes')
SHA='0d294769d55984684f8fe3299f47b7f4da8667b1dabb94ab8e4c620750bf7f87'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--install',action='store_true');args=ap.parse_args()
 old=ORIGINAL.read_bytes();smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
 assert hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(smb).hexdigest()==SMBSHA
 for p in ['build','dist']:(ROOT/p).mkdir(exist_ok=True)
 from graphics import build as art
 graphics=art(smb)
 native=old[16:32784]
 word=lambda a:int.from_bytes(native[a-0x8000:a-0x7ffe],'little')
 stats=[]
 for i in range(6):
  addr=word(0x8b69+i*2);stats.append(native[addr-0x8000:addr-0x8000+72])
 (ROOT/'build/native-stats.bin').write_bytes(b''.join(stats))
 text=''
 for name in ['MARIO','LUIGI']:
  text+=''.join(x.center(12)for x in [name,'FIRE POWER','A KICK','B PUNCH FIRE','DOWN A PIN','START PAUSE'])
 (ROOT/'build/mario-stats.bin').write_bytes(bytes(0 if c==' 'else ord(c)+0x7b for c in text))
 (ROOT/'build/native-portraits.bin').write_bytes(native[0xe10:0xe1c])
 (ROOT/'build/native-names.bin').write_bytes(native[0x1eaf:0x1ebb])
 descriptors=[native[word(0xbb28+i*2)-0x8000:word(0xbb28+i*2)-0x8000+80]for i in range(6)]
 (ROOT/'build/hurt.bin').write_bytes(bytes(p[0x25]for p in descriptors))
 (ROOT/'build/hurt-back.bin').write_bytes(bytes(p[0x26]for p in descriptors))
 (ROOT/'build/down.bin').write_bytes(bytes(p[0x34]for p in descriptors))
 pin_actions=[];pin_holds=[]
 for i,d in enumerate(descriptors[:2]):
  action=d[0x10];table=int.from_bytes(d[0x15:0x17],'little');script=word(table+action*2)
  hold=native[script-0x8000:script-0x8000+64].index(0x5B)
  assert native[script-0x8000+hold+1:script-0x8000+hold+3]==b'\x41\x0c'
  pin_actions.append(action);pin_holds.append(hold)
 (ROOT/'build/pin-action.bin').write_bytes(bytes(pin_actions))
 (ROOT/'build/pin-hold.bin').write_bytes(bytes(pin_holds))
 cc=BASE/'vendor/smb1base/tools/Windows/cc65/bin'
 subprocess.run([str(cc/'ca65.exe'),'src/mario.s','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
 subprocess.run([str(cc/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
 labels={name:int(addr,16)for addr,name in re.findall(r'al ([0-9a-fA-F]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
 rom=bytearray(old[:16]+old[16:]+b'\xff'*(4*32768));rom[4]=16;rom[10]=7
 changes=[]
 def put(a,data,expected=None):
  off=16+a-0x8000
  if expected:assert rom[off:off+len(bytes.fromhex(expected))]==bytes.fromhex(expected),(hex(a),expected)
  rom[off:off+len(data)]=data;changes.append({'cpu':hex(a),'length':len(data)})
 def hook(a,label,expected,op=0x20):
  v=labels[label];put(a,bytes([op,v&255,v>>8]),expected)
 bridge=(ROOT/'build/bridge.bin').read_bytes()
 for b in range(4):rom[16+b*32768+0x7f32:16+b*32768+0x7ffa]=bridge
 bank=(ROOT/'build/bank4.bin').read_bytes();rom[16+4*32768:16+4*32768+len(bank)]=bank
 # Stable cross-bank call/return and reset trampoline, identical in every bank.
 for b in range(4,8):
  rom[16+b*32768+0x7f00:16+b*32768+0x7f32]=old[16+0x7f00:16+0x7f32]
  rom[16+b*32768+0x7f32:16+b*32768+0x7ffa]=bridge
  rom[16+b*32768+0x7ffa:16+(b+1)*32768]=bytes.fromhex('31 ff 22 ff 31 ff')
 pattern=(ROOT/'build/pattern-copy.bin').read_bytes()
 for b in [1,2,3]:
  assert old[16+b*32768+0x7f32:16+b*32768+0x7ffa]==b'\xFF'*200
  rom[16+b*32768+0x7f32:16+b*32768+0x7ffa]=pattern
 # The original graphics generators still calculate every native pose,
 # bound and body offset. Skip only their unused human tile-byte copies.
 for b,start,continuation in [(1,0x8407,0x8458),(2,0x8975,0x89C6),(3,0x80CF,0x8120)]:
  offset=16+b*32768+start-0x8000
  assert rom[offset:offset+6]==bytes.fromhex('A0 00 B1 21 91 25')
  rom[offset:offset+6]=bytes([0x20,0x32,0xFF,0x4C,continuation&255,continuation>>8])
  changes.append({'bank':b,'cpu':hex(start),'length':6})
 hook(0xA040,'InitBridge','20 A5 D1')
 hook(0xAD67,'DrawBridge','20 2E A6')
 put(0xA704,bytes.fromhex('A9 04 A0 1E 20 00 FF 4C B1 A7 EA'),'A0 00 A9 04 85 1C A5 8D 4A 90 06')
 hook(0xAE52,'UpdateBridge','20 4A A2')
 hook(0xAF4D,'ControlBridge','B5 CB F0',0x4C)
 # Native dynamic wrestler CHR and split code stay intact. The Mario
 # poses share the native wrestler packets; selection uploads retain the
 # native unrolled transfer cadence to finish inside their blanking window.
 put(0xAD08,b'\xEF','D2')
 put(0xA0A0,b'\xEF','D2')
 hook(0xA001,'ChoiceMaxBridge','A9 05 85',0x4C)
 hook(0xA00F,'ChoiceLimitBridge','C9 06 90',0x4C)
 put(0xA017,b'\x60','AD') # duplicates allowed for party/tournament participants
 hook(0x9F31,'RosterBridge','AD 00 01',0x4C)
 hook(0x8DAA,'PortraitBridge','0A AA BD',0x4C)
 hook(0x8E1C,'MenuInfoBridge','A5 6D 0A',0x4C)
 hook(0xD603,'NameBridge','BD 25 01',0x4C)
 out=bytes(rom);meta={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':{},'graphics':graphics,'hooks':changes,'mapper':7,'prg_kib':256}
 for p in [ROOT/'build/manifest.json',ROOT/'dist/build-manifest.json']:p.write_text(json.dumps(meta,indent=2))
 (ROOT/'dist'/f'{NAME}.nes').write_bytes(out)
 spec=importlib.util.spec_from_file_location('assets',BASE/'tools/build.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
 (ROOT/'dist'/f'{NAME}.ips').write_bytes(a.ips(old,out))
 if(ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
 if args.install:
  receipt=json.loads((ROOT/'dist/verification.json').read_text());assert receipt['rom_sha256']==meta['output_sha256']and receipt['passed']and all(c['passed']for c in receipt['checks'])
  for ext in ['nes','ips']:
   src=ROOT/'dist'/f'{NAME}.{ext}';dest=ensure_install_dir()/src.name
   if dest.exists()and dest.read_bytes()!=src.read_bytes():
    backup=dest.with_name(dest.stem+' - backup '+hashlib.sha256(dest.read_bytes()).hexdigest()[:8]+dest.suffix)
    if not backup.exists():backup.write_bytes(dest.read_bytes())
   dest.write_bytes(src.read_bytes())
  for src,suffix in [(ROOT/'README.md',' - Readme.txt'),(ROOT/'dist/verification.json',' - verification.json')]: (ensure_install_dir()/(NAME+suffix)).write_bytes(src.read_bytes())
 print('Built',NAME,meta['output_sha256'])
if __name__=='__main__':main()
