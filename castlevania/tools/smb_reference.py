"""Resolve original SMB labels, requiring a byte-for-byte matching PRG build."""
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
SMB=Path('C:/nes/Super Mario Bros. (World).nes')

def labels():
    folder=ROOT/'build/smb-reference'
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'smb.chr').write_bytes(SMB.read_bytes()[0x8010:])
    source=(ROOT/'reference/smb/src/main.asm').read_text()
    source=source.replace('.incbin "../Super Mario Bros. (World).nes", $8010','.incbin "smb.chr"')
    (folder/'main.asm').write_text(source)
    subprocess.run([str(ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin/ca65.exe'),'main.asm','-I','../../reference/smb/src','-g','-o','main.o'],cwd=folder,check=True)
    subprocess.run([str(ROOT.parent/'vendor/smb1base/tools/Windows/cc65/bin/ld65.exe'),'-C','../../reference/smb/layout','main.o','-o','main.nes','--dbgfile','main.dbg'],cwd=folder,check=True)
    assert (folder/'main.nes').read_bytes()[16:0x8010]==SMB.read_bytes()[16:0x8010], 'SMB reference code must exactly match the supplied ROM'
    result={}
    for line in (folder/'main.dbg').read_text().splitlines():
        if line.startswith('sym\t'):
            name=re.search(r'name="([^"]+)"',line)
            value=re.search(r'val=(0x[0-9A-Fa-f]+)',line)
            if name and value: result[name[1]]=int(value[1],16)
    return result

if __name__=='__main__':
    result=labels()
    print({key:hex(result[key]) for key in ('PlayerMovementSubs','PlayerCtrlRoutine','PlayerBGCollision','BlockBufferCollision','ImpedePlayerMove')})
