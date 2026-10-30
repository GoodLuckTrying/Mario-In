"""Assemble an exact reference using graphics from the user's local ROM."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parent/'vendor/tetris-nes'
CC65=ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin'
BASE=Path('C:/nes/Tetris (USA).nes')
SHA='ddb876c302cfd4ee19fabff8e3ede0b6801ded70c49980d1682a32d352953082'
def main():
    rom=BASE.read_bytes();assert hashlib.sha256(rom).hexdigest()==SHA
    build=ROOT/'build';build.mkdir(parents=True,exist_ok=True)
    for i,name in enumerate(['title_menu','typeB_ending','typeA_ending','game']):
        (REPO/'gfx'/f'{name}_tileset.chr').write_bytes(rom[0x8010+i*4096:0x9010+i*4096])
    objects=[]
    for name in ['tetris-ram','tetris']:
        obj=build/(name+'.o');objects.append(str(obj))
        subprocess.run([str(CC65/'ca65.exe'),'--debug-info',name+'.asm','-o',str(obj)],cwd=REPO,check=True)
    subprocess.run([str(CC65/'ld65.exe'),'-C','tetris.nes.cfg','--dbgfile',str(build/'native.dbg'),'-Ln',str(build/'native.labels'),'-m',str(build/'native.map'),'-o',str(build/'native.nes'),*objects],cwd=REPO,check=True)
    reference=(build/'native.nes').read_bytes()
    assert reference[16:]==rom[16:],'Reference PRG and CHR must exactly match the user ROM'
    symbols={}
    for line in (build/'native.dbg').read_text().splitlines():
        kind,_,rest=line.partition('\t');fields=dict(re.findall(r'(\w+)=("[^"]*"|[^,]+)',rest))
        if kind=='sym' and fields.get('type')=='lab' and 'val' in fields:
            name=fields['name'].strip('"')
            if not name.startswith('@'):symbols[name]=int(fields['val'],0)
    for name,value in re.findall(r'^(\w+)\s*:?=\s*\$([0-9A-Fa-f]+)',(REPO/'main.asm').read_text(),re.M):
        if name not in symbols:symbols[name]=int(value,16)
    (build/'native-symbols.json').write_text(json.dumps(symbols,indent=2))
    print('Tetris reference PRG/CHR matches exactly;',len(symbols),'symbols')
if __name__=='__main__':main()
