from pathlib import Path
import argparse,hashlib,importlib.util,json,re,subprocess,sys
from native import ROOT,REPO,CC65,BASE,SHA
sys.path.insert(0, str(ROOT.parent / 'tools'))
from port_paths import ensure_install_dir
NAME='Mario in Tetris'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
def main():
    p=argparse.ArgumentParser();p.add_argument('--install',action='store_true');args=p.parse_args()
    old=BASE.read_bytes();smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
    assert hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(smb).hexdigest()==SMBSHA
    for directory in ['build','dist']:(ROOT/directory).mkdir(exist_ok=True)
    symbols=json.loads((ROOT/'build/native-symbols.json').read_text())
    (ROOT/'src/native.inc').write_text('\n'.join(f'N_{k}=${v:04X}' for k,v in symbols.items() if 0<=v<=65535)+'\n')
    spec=importlib.util.spec_from_file_location('assets',ROOT.parent/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets);assets.ROOT=ROOT;assets.graphics(smb)
    frames=(ROOT/'build/mario-frames.chr').read_bytes();poses=[23,12,13,14,16,22,15]
    chr=bytearray(128*1024);chr[:16384]=old[0x8010:]
    for i,pose in enumerate(poses):
        bank=bytearray(old[0xB010:0xC010])
        bank[0xF00:0xF40]=frames[pose*128+64:pose*128+128]
        chr[(i+4)*4096:(i+5)*4096]=bank
    subprocess.run([str(CC65/'ca65.exe'),'src/mario.s','-I','src','--debug-info','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
    subprocess.run([str(CC65/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
    labels={m[1]:int(m[0],16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
    chr[30*4096:]=(ROOT/'build/hack.bin').read_bytes()
    prg=bytearray(old[16:0x8010]);changes=[]
    def put(addr,data,expected=None):
        off=addr-0x8000
        if expected is not None:assert bytes(prg[off:off+len(expected)])==expected,(hex(addr),expected.hex())
        prg[off:off+len(data)]=data;changes.append({'address':addr,'length':len(data)})
    def hook(addr,name,expected,op=0x20):
        v=labels[name];put(addr,bytes([op,v&255,v>>8]),expected)
    put(0xD6C9,(ROOT/'build/boot.bin').read_bytes())
    # Native code uses INC initRam as an MMC1 reset; its $A2 opcode must
    # retain bit 7. Redirect the following JMP, preserving that reset port.
    init=symbols['initRamContinued']
    hook(symbols['initRam']+2,'Boot',bytes([0x4C,init&255,init>>8]),0x4C)
    hook(symbols['changeCHRBank0'],'TrackChr0',bytes.fromhex('8D FF BF'),0x4C)
    # Redirect dispatch-table entries without disturbing native menu code.
    def dispatch(table,index,native,replacement):
        target=symbols[native];dest=labels[replacement]
        put(symbols[table]+5+index*2,bytes([dest&255,dest>>8]),bytes([target&255,target>>8]))
    dispatch('branchOnGameMode',2,'gameMode_gameTypeMenu','MenuGate')
    dispatch('branchOnPlayStatePlayer1',1,'playState_playerControlsActiveTetrimino','VControls')
    dispatch('branchOnPlayStatePlayer1',2,'playState_lockTetrimino','VLock')
    dispatch('branchOnPlayStatePlayer1',5,'playState_updateLinesAndStatistics','VStats')
    hook(symbols['copyOamStagingToOam'],'DmaGate',bytes.fromhex('A9 00 8D'),0x4C)
    a=symbols['gameModeState_initGameState']+6
    dest=symbols['memset_page'];hook(a,'SessionGate',bytes([0x20,dest&255,dest>>8]))
    a=symbols['gameModeState_updatePlayer1']+3;dest=symbols['branchOnPlayStatePlayer1']
    hook(a,'UpdateGate',bytes([0x20,dest&255,dest>>8]))
    a=symbols['gameModeState_updatePlayer1']+12;dest=symbols['stageSpriteForNextPiece']
    hook(a,'DrawGate',bytes([0x20,dest&255,dest>>8]))
    # These redundant game-bank selections originally ran every visible
    # frame. Gameplay setup already selected both banks; animation now
    # changes the sprite bank during NMI and must retain it until next NMI.
    a=symbols['gameModeState_updateCountersAndNonPlayerState']
    c0=symbols['changeCHRBank0'];c1=symbols['changeCHRBank1']
    put(a,b'\xEA'*10,bytes([0xA9,3,0x20,c0&255,c0>>8,0xA9,3,0x20,c1&255,c1>>8]))
    put(symbols['game_palette']+32,bytes([0x16,0x27,0x18]))
    header=bytearray(old[:16]);header[5]=16;header[8]=0;header[10]=7
    out=bytes(header+prg+chr)
    (ROOT/'dist'/f'{NAME}.nes').write_bytes(out)
    (ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
    report={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':symbols,'hooks':changes,'poses':poses,'controls':'Solo shared / VS P1 Mario, P2 or CPU pieces / Select+Start Auto-Classic','mapper':'MMC1 with 8 KiB WRAM','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip()}
    for path in [ROOT/'build/manifest.json',ROOT/'dist/build-manifest.json']:path.write_text(json.dumps(report,indent=2))
    if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
    if args.install:
        receipt=json.loads((ROOT/'dist/verification.json').read_text())
        assert receipt['rom_sha256']==report['output_sha256'] and receipt['passed'] and all(c['passed'] for c in receipt['checks']),'Verify this exact build before installing'
        for ext in ['nes','ips']:
            source=ROOT/'dist'/f'{NAME}.{ext}';dest=ensure_install_dir()/source.name
            if dest.exists() and dest.read_bytes()!=source.read_bytes():
                backup=dest.with_name(dest.stem+' - backup '+hashlib.sha256(dest.read_bytes()).hexdigest()[:8]+dest.suffix)
                if not backup.exists():backup.write_bytes(dest.read_bytes())
            dest.write_bytes(source.read_bytes())
        (ensure_install_dir()/(NAME+' - verification.json')).write_bytes((ROOT/'dist/verification.json').read_bytes())
        (ensure_install_dir()/(NAME+' - Readme.txt')).write_bytes((ROOT/'README.md').read_bytes())
    print('Built '+NAME+' '+report['output_sha256'])
if __name__=='__main__':main()
