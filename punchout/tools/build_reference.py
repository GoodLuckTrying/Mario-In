from pathlib import Path
import subprocess, hashlib, json
ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'punchout'; V=ROOT/'vendor/punchout-disassembly'
BASE=Path("C:/nes/Mike Tyson's Punch-Out!! (Japan, USA) (En) (Rev 1).nes")
BASE_SHA='e1e7ea03309e370240e90ad80815b484e1c537107d8620e2479f8169cf237c8f'
def sha(b):return hashlib.sha256(b).hexdigest()
def build():
    rom=BASE.read_bytes();assert sha(rom)==BASE_SHA
    out=P/'build/reference';out.mkdir(parents=True,exist_ok=True)
    names=[f'PRG_Bank{i:03X}'for i in range(13)]+['PRG_BankDEF']
    chunks=[]
    for name in names:
        target=out/(name+'.bin')
        subprocess.run([str(V/'ophis/ophis.exe'),name+'.asm',str(target)],cwd=V/'source_files',capture_output=True,check=True)
        chunks.append(target.read_bytes())
    prg=b''.join(chunks);assert prg==rom[16:16+0x20000]
    chr_files=sorted((V/'binaries').glob('CHR*'))
    if not chr_files:chr_files=sorted(V.rglob('CHR_Bank*.bin'))
    chrdata=b''.join(p.read_bytes()for p in chr_files)
    assert chrdata==rom[16+0x20000:],[(p.name,p.stat().st_size)for p in chr_files]
    info=dict(base_rom=BASE.as_posix(),base_sha256=BASE_SHA,prg_sha256=sha(prg),chr_sha256=sha(chrdata),
              matching_prg=True,matching_chr=True,source_revision='60b2fa0e61d57b10b5fadc04be96241d25755d25')
    (out/'source-verification.json').write_text(json.dumps(info,indent=2)+'\n')
    return rom,info
if __name__=='__main__':build();print('Exact Rev 1 PRG and CHR reconstruction passed.')
