from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,importlib.util
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from research import BASE,rom as original
from native_art import sequence
CC65=ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin'
SHA='8d5e3d9ce20fa0a61b23e93dbc975606803f2d5e7a264514b02b96f832a63181'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
NAME='Mario and Luigi in Rescue Rangers'
def main():
 p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');args=p.parse_args()
 assert hashlib.sha256(original).hexdigest()==SHA
 smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes();assert hashlib.sha256(smb).hexdigest()==SMBSHA
 (ROOT/'build').mkdir(exist_ok=True);(ROOT/'dist').mkdir(exist_ok=True)
 spec=importlib.util.spec_from_file_location('icarus_build',ROOT.parent/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets);assets.graphics(smb)
 states=[]
 for line in (ROOT.parent/'src/memory.inc').read_text().splitlines():
  m=re.fullmatch(r'(M_\w+)=\$68([0-9A-F]{2})',line)
  if m and int(m[2],16)<=0x45:states.append(f'{m[1]}=$69{m[2]}')
 states+=['M_TRANSFORM=$6946','M_STOMP_GRACE=$6949','M_STOMP_CHAIN=$694A','M_SUPPLIES=$694C','M_DROP=$694D','M_Y_PAGE=$694E','M_PREV_PAGE=$694F']
 (ROOT/'src/state.inc').write_text('\n'.join(states)+'\n')
 (ROOT/'src/smb-land.inc').write_text((ROOT.parent/'src/smb-land.inc').read_text())
 # Pack exact SMB tiles into CHR slots exclusively owned by the old players.
 players=set();others=set()
 for i in range(1,169):
  try:s=sequence(i)
  except IndexError:continue
  if i<=24 or i in [0x29,0x2A,0x99,0x9A,0xA1,0xA5]:players|=s
  else:others|=s
 free=sorted(players-others);assert len(free)==79
 frames=(ROOT.parent/'build/mario-frames.chr').read_bytes()
 selected=[0,1,2,3,4,10,12,13,14,15,16,17,22,23,24,25]
 packed={};tiledata={}
 def tile(t):
  flipped=bytes(int(f'{v:08b}'[::-1],2) for v in t)
  canonical=min(t,flipped)
  if canonical not in packed:
   slot=free[len(packed)];packed[canonical]=slot;tiledata[slot]=canonical
  return packed[canonical],0x40 if t!=canonical else 0
 frame_table=bytearray()
 for f in range(26):
  if f not in selected:f=4 if f<12 else 16
  for i in range(8):frame_table.extend(tile(frames[f*128+i*16:f*128+(i+1)*16]))
 chr=smb[0x8010:];items=[]
 for ids in [[0x76,0x77,0x78,0x79],[0xD6,0xD6,0xD9,0xD9],[0x64]]:
  for i,t in enumerate(ids):
   data=chr[t*16:t*16+16]
   if ids[0]==0xD6 and i%2:data=bytes(int(f'{v:08b}'[::-1],2) for v in data)
   items.extend(tile(data))
 assert len(packed)<=len(free)
 (ROOT/'build/frames.bin').write_bytes(frame_table);(ROOT/'build/items.bin').write_bytes(bytes(items))
 subprocess.run([str(CC65/'ca65.exe'),'src/mario.s','-I','src','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
 subprocess.run([str(CC65/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
 labels={m[1]:int(m[0],16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
 old=original;header=bytearray(old[:16]);header[4]=16;header[10]=7
 prg=bytearray(b'\xff'*(256*1024));prg[:128*1024]=old[16:16+128*1024];prg[15*16384:]=old[16+7*16384:16+8*16384];prg[8*16384:9*16384]=(ROOT/'build/bank8.bin').read_bytes()
 changes=[]
 def put(bank,addr,data,expected=None):
  offset=bank*16384+addr-(0xC000 if bank==15 else 0x8000)
  if expected:assert prg[offset:offset+len(bytes.fromhex(expected))]==bytes.fromhex(expected),(bank,hex(addr))
  prg[offset:offset+len(data)]=data;changes.append({'bank':bank,'address':addr,'length':len(data)})
 def hook(bank,addr,name,expected,op=0x20):
  a=labels[name];put(bank,addr,bytes([op,a&255,a>>8]),expected)
 put(15,0xFC49,(ROOT/'build/fixed.bin').read_bytes())
 hook(15,0xFE67,'Boot','20 1E C2')
 hook(15,0xC8EE,'MoveGate','B4 56 F0',0x4C)
 hook(15,0xC837,'DrawGate','20 00 80')
 hook(15,0xC021,'DmaGate','A9 02 8D');put(15,0xC024,b'\xea\xea','14 40')
 hook(15,0xC21E,'ClearGate','A6 97 E0',0x4C)
 hook(15,0xD1DC,'DeathGate','B5 56 F0',0x4C)
 hook(5,0x8129,'SpriteGate','BD 00 04',0x4C)
 # The fixed enemy contact dispatch now uses Mario's shape and stomp crossing.
 hook(6,0x8035,'ContactGate','B9 5E 00',0x4C)
 hook(15,0xF92B,'CollisionGate','A0 00 B9',0x4C)
 hook(6,0x8009,'ActorGate','BC E0 04',0x4C)
 hook(15,0xF977,'ObjectHitGate','86 05 A0',0x4C)
 hook(15,0xC235,'ResetGate','A2 0F A9',0x4C)
 hook(15,0xEB0C,'CollectibleGate','20 F5 F3')
 hook(15,0xF868,'PickupObjectGate','98 09 80',0x4C)
 hook(15,0xC06E,'PaletteUpload','BD 00 03',0x4C)
 # A point left of the world must return empty, not reuse stale Y scratch.
 put(15,0xEB56,bytes.fromhex('30 5D'),'30 48')
 chrout=bytearray(old[16+128*1024:])
 for bank in range(13):
  for slot,data in tiledata.items():chrout[bank*4096+slot*16:bank*4096+(slot+1)*16]=data
 out=bytes(header+prg+chrout);dest=ROOT/'dist'/f'{NAME}.nes';dest.write_bytes(out)
 (ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
 report={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':{},'hooks':changes,'chr_tiles':len(packed),'prg_kib':256,'wram_kib':8}
 (ROOT/'build/manifest.json').write_text(json.dumps(report,indent=2))
 (ROOT/'dist/build-manifest.json').write_text(json.dumps(report,indent=2))
 if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
 if args.install:
  verification=ROOT/'dist/verification.json'
  assert verification.exists(),'Verify the candidate before installing it'
  receipt=json.loads(verification.read_text())
  assert receipt.get('rom_sha256')==report['output_sha256'] and receipt.get('checks') and all(check['passed'] for check in receipt['checks']),'Installation requires every check to pass for this exact ROM'
  for ext in ['nes','ips']:
   source=dest.with_suffix('.'+ext);target=Path('C:/nes')/source.name
   if target.exists() and target.read_bytes()!=source.read_bytes():
    backup=target.with_name(target.stem+' - backup '+hashlib.sha256(target.read_bytes()).hexdigest()[:8]+target.suffix)
    if not backup.exists():backup.write_bytes(target.read_bytes())
   target.write_bytes(source.read_bytes())
  if (ROOT/'README.md').exists():(Path('C:/nes')/f'{NAME} - Readme.txt').write_bytes((ROOT/'README.md').read_bytes())
  verification=ROOT/'dist/verification.json'
  if verification.exists():
   receipt=json.loads(verification.read_text())
   if receipt.get('rom_sha256')==report['output_sha256'] and all(check['passed'] for check in receipt['checks']):
    (Path('C:/nes')/f'{NAME} - verification.json').write_bytes(verification.read_bytes())
 print('Built',len(out),'bytes;',report['output_sha256'],'CHR slots',len(packed))
if __name__=='__main__':main()
