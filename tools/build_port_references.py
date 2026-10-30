"""Rebuild pinned, unmodified host disassemblies; never edits a local ROM."""
from pathlib import Path
import argparse,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
CC=ROOT/'vendor/smb1base/tools/Windows/cc65/bin'
PROJECTS={
 'megaman2':('mm2-reference','da9b91ae1793db0c736f92d96554eb724882326d','Mega Man 2 (USA).nes','mm2-reference.nes','labels.txt'),
 'metroid':('metroid-reference','efbd348d7251463d6179775fc6e901207d210610','Metroid (USA).nes','metroid-reference.nes','metroid-reference.sym')}
def sha(data):return hashlib.sha256(data).hexdigest()
def ensure_reference(game,rebuild=False):
 folder,revision,name,output,symbols=PROJECTS[game]
 src=ROOT/'vendor'/folder;out=ROOT/'build'/folder;out.mkdir(parents=True,exist_ok=True)
 actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=src,text=True).strip()
 assert actual==revision,('Unpinned upstream',src,actual)
 assert not subprocess.check_output(['git','diff','--name-only'],cwd=src,text=True).strip(),'Reference source must remain unmodified'
 base=Path('C:/nes')/name;original=base.read_bytes()
 receipt=out/'baseline.json'
 cached=json.loads(receipt.read_text()) if receipt.exists() else {}
 valid=(out/output).exists() and (out/symbols).exists()
 if valid:
  valid=cached.get('symbols_sha256')==sha((out/symbols).read_bytes()) and (out/output).read_bytes()[16:]==original[16:]
 if rebuild or not valid:
  if game=='megaman2':
   objects=[]
   for asm in sorted((src/'src').glob('bank*.asm'))+[src/'src/header.asm']:
    obj=out/(asm.stem+'.o');objects.append(obj)
    subprocess.run([str(CC/'ca65.exe'),'-g','-I','.',str(asm.relative_to(src)),'-o',str(obj),'-l',str(out/(asm.stem+'.lst'))],cwd=src,check=True)
   subprocess.run([str(CC/'ld65.exe'),'-C','cfg/nes.cfg','-o',str(out/output),'-Ln',str(out/symbols),'--dbgfile',str(out/'debug.txt'),*map(str,objects)],cwd=src,check=True)
  else:
   wla=ROOT/'vendor/wla-dx-10.7/wla_dx_v10.7_Win64'
   objects=[]
   for asm in sorted((src/'SRC').glob('prg*.asm')):
    obj=out/(asm.stem+'.o');objects.append(obj)
    subprocess.run([str(wla/'wla-6502.exe'),'-h','-w','-D','BUILDTARGET="NES_NTSC"','-o',str(obj),'-I','SRC',str(asm.relative_to(src))],cwd=src,check=True)
   lines=['[header]','"'+(src/'SRC/header.bin').as_posix()+'"','[objects]']+['"'+obj.as_posix()+'"' for obj in objects]
   (out/'linkfile').write_text('\n'.join(lines)+'\n')
   subprocess.run([str(wla/'wlalink.exe'),'-C','-S',str(out/'linkfile'),str(out/output)],cwd=src,check=True)
  rebuilt=(out/output).read_bytes();assert rebuilt[16:]==original[16:],'Upstream payload must reproduce the local original exactly'
  cached=dict(source_revision=revision,base_rom=str(base),base_sha256=sha(original),build_sha256=sha(rebuilt),payload_exact=True,
   header_difference_offsets=[i for i in range(16) if rebuilt[i]!=original[i]],symbols_sha256=sha((out/symbols).read_bytes()))
  receipt.write_text(json.dumps(cached,indent=2)+'\n')
 assert cached['base_sha256']==sha(original) and cached['payload_exact']
 return out
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('games',nargs='*',choices=list(PROJECTS));parser.add_argument('--rebuild',action='store_true');args=parser.parse_args()
 for game in args.games or PROJECTS:print(game,ensure_reference(game,args.rebuild))
