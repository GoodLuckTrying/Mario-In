"""Install only an exact-hash passing Karnov/Rygar build, preserving originals."""
from pathlib import Path
import argparse,shutil
from check_release import check_release
from native_port_common import install,SMB
from port_paths import INSTALL_DIR, ensure_install_dir
ROOT=Path(__file__).resolve().parents[1]

def main():
 parser=argparse.ArgumentParser();parser.add_argument('game',choices=['karnov','rygar']);game=parser.parse_args().game
 p=ROOT/game;name='Mario in '+game.capitalize();rom=p/'dist'/f'{name}.nes';patch=rom.with_suffix('.ips');manifest=p/'build/manifest.json';receipt=p/'dist/verification.json'
 base=Path('C:/nes')/(game.capitalize()+' (USA).nes')
 check_release(rom,manifest,receipt,base=base,smb=SMB,ips=patch)
 install(p,name)
 for source,dest in [(receipt,name+' - verification.json'),(p/'README.md',name+' - Readme.txt')]:shutil.copyfile(source,ensure_install_dir()/dest)
 check_release(rom,manifest,receipt,base=base,smb=SMB,ips=patch,installed=INSTALL_DIR/rom.name)
 print('Installed and byte-verified',name)
if __name__=='__main__':main()
