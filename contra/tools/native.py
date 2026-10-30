"""Extract local Contra assets and assemble its reference disassembly."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parent/'vendor/contra-us'
CC65=ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin'
BASE=Path('C:/nes/Contra (USA).nes')
SHA='1f4a9b3f04e2f828688512c0b83611a87c3fc1bd4f85ed91da1b19abc5816d73'
def main():
    rom=BASE.read_bytes()
    assert hashlib.sha256(rom).hexdigest()==SHA,'Unexpected Contra base'
    build=ROOT/'build';build.mkdir(exist_ok=True)
    for line in (REPO/'assets.txt').read_text().splitlines():
        path,start,length=line.split()
        dest=REPO/Path(path.replace('\\','/'))
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(rom[int(start):int(start)+int(length)])
    names=['ram','constants','ines_header']+[f'bank{i}' for i in range(8)]
    objects=[]
    for name in names:
        obj=build/(name+'.o');objects.append(str(obj))
        subprocess.run([str(CC65/'ca65.exe'),'-D','Contra','--debug-info','-o',str(obj),f'src/{name}.asm'],cwd=REPO,check=True)
    subprocess.run([str(CC65/'ld65.exe'),'-C','contra.cfg','--dbgfile',str(build/'native.dbg'),'-Ln',str(build/'native.labels'),'-m',str(build/'native.map'),'-o',str(build/'native.nes'),*objects],cwd=REPO,check=True)
    assert (build/'native.nes').read_bytes()[16:]==rom[16:],'Reference PRG must exactly match the local ROM'
    segments={};symbols={}
    for line in (build/'native.dbg').read_text().splitlines():
        kind,_,rest=line.partition('\t')
        fields=dict(re.findall(r'(\w+)=("[^"]*"|[^,]+)',rest))
        if kind=='seg':segments[fields['id']]=fields['name'].strip('"')
        if kind=='sym' and fields.get('type')=='lab' and fields.get('seg'):
            name=fields['name'].strip('"')
            if not name.startswith('@'):
                symbols[name]={'address':int(fields['val'],0),'segment':fields['seg']}
    for value in symbols.values():value['segment']=segments[value['segment']]
    (build/'native-symbols.json').write_text(json.dumps(symbols,indent=2))
    print('Contra reference PRG matches exactly;',len(symbols),'labels indexed')
if __name__=='__main__':main()
