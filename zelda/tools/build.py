"""Build against the user's exact PRG0 Zelda ROM; originals stay untouched."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re,shutil,subprocess,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parent/'vendor/zelda'
CC65=ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin'
BASE=Path('C:/nes/Legend of Zelda, The (USA).nes')
SMB=Path('C:/nes/Super Mario Bros. (World).nes')
SHA='1dff2d002168e0234d206938afc5189a79eb0ec055ada12f2cd4e105f713fc7d'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
COMMIT='50a1c869a8d8e2eb8b5b60acea325f44b4341762'
NAME='Mario in The Legend of Zelda'
def edit(source,file,before,after):
 p=source/'src'/file;s=p.read_text();assert s.count(before)==1,(file,before[:80],s.count(before));p.write_text(s.replace(before,after))
def symbols(path):
 labels={}
 for line in path.read_text().splitlines():
  if not line.startswith('sym\t'):continue
  fields=dict(re.findall(r'(\w+)=("[^"]*"|[^,]+)',line))
  if 'val'in fields and 'name'in fields and not fields['name'].startswith('"@'):
   labels[fields['name'].strip('"')]=int(fields['val'],0)
 return labels
def assemble(source,name):
 objects=[]
 for src in sorted((source/'src').glob('Z_*.asm')):
  obj=source/'obj'/(src.stem+'.o');objects.append(str(obj))
  subprocess.run([str(CC65/'ca65.exe'),str(src),'-g','--bin-include-dir',str(source/'bin'),'-I',str(source/'src'),'-o',str(obj)],check=True,capture_output=True,text=True)
 target=ROOT/'build'/(name+'.bin');dbg=target.with_suffix('.dbg')
 subprocess.run([str(CC65/'ld65.exe'),'-C',str(source/'src/Z.cfg'),'-o',str(target),'--dbgfile',str(dbg),'-Ln',str(target.with_suffix('.lbl')),'-m',str(target.with_suffix('.map')),*objects],check=True,capture_output=True,text=True)
 labels=symbols(dbg)
 for addr,name in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',target.with_suffix('.lbl').read_text()):labels[name]=int(addr,16)
 return target.read_bytes(),labels
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--native-only',action='store_true');ap.add_argument('--install',action='store_true');args=ap.parse_args()
 old=BASE.read_bytes();smb=SMB.read_bytes()
 assert hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(smb).hexdigest()==SMBSHA
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip()==COMMIT
 for folder in ['build','dist']:(ROOT/folder).mkdir(exist_ok=True)
 source=ROOT/'build/source';shutil.copytree(REPO,source,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.git','bin','obj'))
 for folder in ['bin','obj']:(source/folder).mkdir(exist_ok=True)
 for b in ET.parse(source/'src/bins.xml').getroot():
  target=source/'bin'/b.attrib['FileName'];target.parent.mkdir(exist_ok=True,parents=True)
  start=int(b.attrib['Offset'])+16;target.write_bytes(old[start:start+int(b.attrib['Length'])])
 native,N=assemble(source,'native');assert native==old[16:],'Exact native PRG reproduction is required'
 (ROOT/'build/native.nes').write_bytes(old[:16]+native)
 if not args.native_only:patch(source,smb)
 payload,H=assemble(source,'patched')
 out=old[:16]+payload
 spec=importlib.util.spec_from_file_location('assets',ROOT.parent/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets)
 (ROOT/'dist'/f'{NAME}.nes').write_bytes(out);(ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
 meta={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'source_commit':COMMIT,'labels':H,'native':N,'mapper':1,'prg_kib':128,'chr_ram_kib':8}
 if not args.native_only:meta['directional_source']=json.loads((ROOT/'build/directional-art.json').read_text())
 for path in [ROOT/'build/manifest.json',ROOT/'dist/build-manifest.json']:path.write_text(json.dumps(meta,indent=2))
 if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
 if args.install:
  receipt=json.loads((ROOT/'dist/verification.json').read_text());assert receipt['passed']and receipt['rom_sha256']==meta['output_sha256']and all(x['passed']for x in receipt['checks'])
  for ext in ['nes','ips']:
   data=(ROOT/'dist'/f'{NAME}.{ext}').read_bytes();target=Path('C:/nes')/f'{NAME}.{ext}'
   if target.exists()and target.read_bytes()!=data:
    backup=target.with_name(target.stem+' - backup '+hashlib.sha256(target.read_bytes()).hexdigest()[:8]+target.suffix)
    if not backup.exists():backup.write_bytes(target.read_bytes())
   target.write_bytes(data)
  for src,suffix in [(ROOT/'dist/verification.json',' - verification.json'),(ROOT/'README.md',' - Readme.txt')]:
   (Path('C:/nes')/(NAME+suffix)).write_bytes(src.read_bytes())
 print('Built',NAME,meta['output_sha256'])
def patch(source,smb):
 sys_path=str(ROOT/'tools')
 import sys
 sys.path.insert(0,sys_path)
 from graphics import build as graphics
 graphics(source,smb)
 for file in (ROOT/'src').iterdir():shutil.copyfile(file,source/'src'/file.name)
 cfg=source/'src/Z.cfg';s=cfg.read_text().replace('size = $1270','size = $1330').replace('    BANK_00_00:','    MARIO_CODE: load = ROM_00, type = ro, start = $8000 ;\n    BANK_00_00:');cfg.write_text(s)
 edit(source,'Z_00.asm','.SEGMENT "BANK_00_00"','.INCLUDE "mario-fire.asm"\n.SEGMENT "BANK_00_00"')
 for file in ['Z_01.asm','Z_05.asm','Z_07.asm']:
  edit(source,file,'.INCLUDE "Variables.inc"','.INCLUDE "Variables.inc"\n.INCLUDE "mario-vars.inc"')
 # The native RAM block has space below $7FC0 after extending it by less
 # than one page. ca65 asserts that the appended helper stays below state.
 edit(source,'Z_01.asm','.SEGMENT "BANK_01_ISR"','.INCLUDE "mario-collision.inc"\n.SEGMENT "BANK_01_ISR"')
 edit(source,'Z_01.asm','    ; Check for collisions with each weapon.','    JSR MarioFireCollision\n\n    ; Check for collisions with each weapon.')
 edit(source,'Z_01.asm','    STA $03                     ; The right tile is two tiles over.','    STA $03                     ; The right tile is two tiles over.\n    .INCLUDE "mario-walk.inc"')
 # The extra Link animation now uses Mario's standing front pose. Its
 # former tiles provide one of the new walking poses.
 edit(source,'Z_01.asm','    .BYTE $5C, $9E, $44, $CE, $D2, $D6, $DA, $CE','    .BYTE $08, $9E, $44, $CE, $D2, $D6, $DA, $CE')
 edit(source,'Z_07.asm','.IMPORT UpdateFireball','.IMPORT MarioFireUpdate,MarioFireRender\n.IMPORT UpdateFireball')
 edit(source,'Z_07.asm','@UpdateWeapons:\n','@UpdateWeapons:\n    LDA #0\n    JSR SwitchBank\n    JSR MarioFireUpdate\n    LDA #5\n    JSR SwitchBank\n')
 edit(source,'Z_07.asm','UpdateHeartsAndRupees:\n','UpdateHeartsAndRupees:\n    LDA #0\n    JSR SwitchBank\n    JSR MarioFireRender\n')
 edit(source,'Z_07.asm','ResetPlayerState:\n    LDA #$00','ResetPlayerState:\n    LDA #0\n    STA M_TTL\n    STA M_TTL+1\n    LDA #$00')
 edit(source,'Z_07.asm','    LDA #$08\n    STA Sprites+77','    LDA #$0A\n    STA Sprites+77\n    LDA Sprites+78\n    AND #$BF\n    STA Sprites+78')
 # Preserve shield behavior, but its replacement head tiles are Link art.
 p=source/'src/Z_07.asm';s=p.read_text();a=s.index("    ; See if there's special processing needed for the shield.");b=s.index('L1F36A_Exit:',a);p.write_text(s[:a]+s[b:])
 for file,label in [('Z_01.asm','LinkColors_CommonCode'),('Z_02.asm','LinkColors')]:
  edit(source,file,label+':\n    .BYTE $29, $32, $16',label+':\n    .BYTE $30, $30, $30')
 edit(source,'Z_06.asm','    .BYTE $12, $1C, $2C, $0F, $29, $27, $07, $0F\n    .BYTE $22, $27, $07, $0F, $26, $27, $07, $0F','    .BYTE $12, $1C, $2C, $0F, $30, $27, $16, $0F\n    .BYTE $30, $27, $16, $0F, $30, $27, $16, $0F')
 for p in (source/'bin/dat').glob('LevelInfo*.dat'):
  data=bytearray(p.read_bytes());data[20:23]=bytes([0x30,0x27,0x16]);p.write_bytes(data)
if __name__=='__main__':
 try:main()
 except subprocess.CalledProcessError as e:
  print(e.stdout);print(e.stderr);raise
