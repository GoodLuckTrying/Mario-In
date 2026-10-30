from pathlib import Path
import argparse,hashlib,importlib.util,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
CC65=ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin'
NAME='Mario in Gradius'
SHA='38c44e0e6f531a2779271f10cd4daa08ee2616c59c49d476b6f4e9dc482bf5f3'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
def main():
 p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');args=p.parse_args()
 old=Path('C:/nes/Gradius (USA).nes').read_bytes();smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
 assert hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(smb).hexdigest()==SMBSHA
 (ROOT/'build').mkdir(exist_ok=True);(ROOT/'dist').mkdir(exist_ok=True)
 spec=importlib.util.spec_from_file_location('icarus_assets',ROOT.parent/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets)
 # Extract only into this project; no changes to the other ports' assets.
 saved=assets.ROOT;assets.ROOT=ROOT;assets.graphics(smb);assets.ROOT=saved
 frames=(ROOT/'build/mario-frames.chr').read_bytes()
 prg=bytearray(old[16:0x8010]);chr=bytearray(128*1024)
 def byte(a):return old[16+a-0x8000]
 def records(i):
  at=0x8d9e+i*2;q=byte(at)|byte(at+1)<<8
  if not 0x8eef<=q<0x9650:return []
  n=byte(q);assert n<64
  return [bytes(byte(q+1+j*4+k) for k in range(4)) for j in range(n)]
 # All genuine native metasprites, plus direct stage-5 arm and split sprites.
 used={0x6c,0xf6,0xf8,0xfa,0xfc}
 for i in range(4,256):
  if i not in [6,0x24]:used|={t[1]&0xfe for t in records(i)}
 available=sorted(set(range(0,256,2))-used)
 assert available==[8,10,12,106,114,222,254],available
 mario=[8,10,12,222];fire=[106,114]
 (ROOT/'src/graphics.inc').write_text('\n'.join([f'MARIO_TILE_{i}=${t|1:02X}' for i,t in enumerate(mario)]+[f'FIRE_TILE_{i}=${t|1:02X}' for i,t in enumerate(fire)]+[f'FIRE_DY={records(6)[0][0]}',f'FIRE_DX={records(6)[0][3]}'])+'\n')
 def recolor(tile,mapping):
  out=bytearray(16)
  for y in range(8):
   for x in range(8):
    color=((tile[y]>>(7-x))&1)|(((tile[y+8]>>(7-x))&1)<<1);v=mapping[color]
    out[y]|=(v&1)<<(7-x);out[y+8]|=(v>>1)<<(7-x)
  return out
 for pose,frame in enumerate([5,6,7]):
  for bank in range(4):
   at=(pose*4+bank)*8192
   chr[at:at+8192]=old[0x8010+bank*8192:0x8010+(bank+1)*8192]
   for pair,indices in zip(mario,[(0,2),(1,3),(4,6),(5,7)]):
    data=b''.join(recolor(frames[frame*128+i*16:frame*128+(i+1)*16],[0,3,2,1]) for i in indices)
    loc=at+4096+pair*16;chr[loc:loc+32]=data
   for pair,tile in zip(fire,[0x64,0x65]):
    data=recolor(smb[0x8010+tile*16:0x8010+(tile+1)*16],[0,1,3,2])+bytes(16)
    loc=at+4096+pair*16;chr[loc:loc+32]=data
 # The original title bank includes its ship-shaped selection pointer.
 # It must not share the player tile replacements used during gameplay.
 chr[13*8192:14*8192]=old[0x8010+3*8192:0x8010+4*8192]
 subprocess.run([str(CC65/'ca65.exe'),'src/mario.s','-I','src','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
 subprocess.run([str(CC65/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
 labels={m[1]:int(m[0],16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
 changes=[]
 def put(a,data,expected=None):
  off=a-0x8000
  if expected:assert prg[off:off+len(bytes.fromhex(expected))]==bytes.fromhex(expected),(hex(a),expected)
  prg[off:off+len(data)]=data;changes.append({'address':a,'length':len(data)})
 def hook(a,name,expected,op=0x20):
  v=labels[name];put(a,bytes([op,v&255,v>>8]),expected)
 put(0xffc0,(ROOT/'build/boot.bin').read_bytes())
 hook(0x8064,'Boot','20 10 85')
 hook(0x8073,'NmiGate','A4 04 D0',0x4c)
 hook(0x8099,'PaletteGate','20 51 8A')
 hook(0x809c,'ScrollGate','20 81 82')
 hook(0x80a4,'InputGate','20 BF 81')
 hook(0x80a7,'DrawGate','20 10 8B')
 put(0x80ad,b'\xea\xea\xea','20 AB 8B')
 hook(0x8085,'DmaGate','A0 02 8C');put(0x8088,b'\xea\xea','14 40')
 hook(0xc1d6,'DeathGate','A5 1B C9',0x4c)
 hook(0x80b0,'PauseGate','20 41 86')
 hook(0xa1e6,'FireLoop','A2 00 86',0x4c)
 hook(0xa24d,'SpawnAEnd','4C 66 A2',0x4c)
 hook(0xa263,'SpawnBEnd','9D 66 01',0x4c)
 hook(0xa043,'FloatGate','A9 01 A0',0x4c)
 hook(0xa0e9,'FireGate','A6 44 BD',0x4c)
 hook(0x9a70,'EarlyCombat','20 E2 BF')
 hook(0x9ac4,'FinishCombat','20 45 9C')
 hook(0xc2c4,'TerrainTail','A2 05 86',0x4c)
 hook(0xc2ca,'TerrainGate','20 AF C3')
 # Exact native instruction timing; FF-filled bus-safe destinations allow
 # the upper CHR bits to select swimming poses without changing stage art.
 put(0x8a9e,bytes.fromhex('B9 D0 70'),'B9 A8 8A')
 put(0x8aa1,bytes.fromhex('99 F5 FF'),'99 A8 8A')
 put(0x8aa4,bytes.fromhex('99 F5 FF'),'99 A8 8A')
 assert prg[0x7ff5:0x7ff9]==b'\xff'*4
 for i,name in [(49,'FireFrame0'),(55,'FireFrame1')]:
  assert records(i)==[]
  put(0x8d9e+i*2,labels[name].to_bytes(2,'little'))
 chr[12*8192:12*8192+4096]=(ROOT/'build/hack.bin').read_bytes()
 header=bytearray(old[:16]);header[5]=16;header[10]=7
 out=bytes(header+prg+chr);(ROOT/'dist'/f'{NAME}.nes').write_bytes(out)
 (ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
 report={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':{},'hooks':changes,'chr_pairs':mario+fire,'swim_frames':[5,6,7],'title_chr_bank':13,'chr_kib':128,'reference_commit':'314625258387309119e69e37aaf3365197235119'}
 (ROOT/'build/manifest.json').write_text(json.dumps(report,indent=2));(ROOT/'dist/build-manifest.json').write_text(json.dumps(report,indent=2))
 if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
 if args.install:
  receipt_path=ROOT/'dist/verification.json'
  receipt=json.loads(receipt_path.read_text())
  assert receipt.get('passed') and receipt.get('rom_sha256')==report['output_sha256'] and all(c['passed']for c in receipt['checks']),'Install requires a successful verification receipt for this exact ROM'
  for ext in ['nes','ips']:
   source=ROOT/'dist'/f'{NAME}.{ext}';target=Path('C:/nes')/source.name
   if target.exists() and source.read_bytes()!=target.read_bytes():
    backup=target.with_name(target.stem+' - backup '+hashlib.sha256(target.read_bytes()).hexdigest()[:8]+target.suffix)
    if not backup.exists():backup.write_bytes(target.read_bytes())
   target.write_bytes(source.read_bytes())
  if (ROOT/'README.md').exists():(Path('C:/nes')/f'{NAME} - Readme.txt').write_bytes((ROOT/'README.md').read_bytes())
  receipt=ROOT/'dist/verification.json'
  if receipt.exists():
   v=json.loads(receipt.read_text())
   if v.get('rom_sha256')==report['output_sha256'] and all(c['passed'] for c in v['checks']):(Path('C:/nes')/f'{NAME} - verification.json').write_bytes(receipt.read_bytes())
 print('Built',NAME,report['output_sha256'])
if __name__=='__main__':main()
