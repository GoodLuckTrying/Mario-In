"""Verified byte hooks for Karnov (USA); no external disassembly required."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import *
P=ROOT/'karnov';NAME='Mario in Karnov';BASE=Path('C:/nes/Karnov (USA).nes')
BASE_SHA='0d49c1120fc13ead1efe4429f7cbb4f01b90e2486c66661c46e922dda6dc830a'

def main():
 for d in ('build','dist'):(P/d).mkdir(exist_ok=True)
 old=BASE.read_bytes();assert sha(old)==BASE_SHA
 from build import graphics
 smb=SMB.read_bytes();assert sha(smb)==SMB_SHA
 graphics(smb,output_dir=P/'build/source-art')
 frames=(P/'build/source-art/mario-frames.chr').read_bytes()
 selected=[0,1,2,24,4,3,10,8,9,11,22]
 chr_old=old[16+131072:];chr_new=bytearray(chr_old)
 for native in [0,1,2,3,24]:
  for pose in selected:
   page=bytearray(chr_old[native*1024:(native+1)*1024])
   src=frames[pose*128:(pose+1)*128]
   # Four 8x16 cells; preserve sprite-zero and all non-player patterns.
   for cell in range(4):
    col=cell%2;row=cell//2
    page[0x200+cell*32:0x220+cell*32]=src[(row*4+col)*16:(row*4+col+1)*16]+src[(row*4+col+2)*16:(row*4+col+3)*16]
   for cell,tile in enumerate([0x64,0x65]):
    page[0x1C0+cell*32:0x1E0+cell*32]=smb[0x8010+tile*16:0x8010+(tile+1)*16]+bytes(16)
   chr_new.extend(page)
 chr_new.extend(bytes(131072-len(chr_new)))
 h=assemble(P)
 prg=bytearray(old[16:16+131072]+b'\xFF'*131072)
 prg[30*8192:]=old[16+14*8192:16+16*8192]
 changes=[]
 def put(bank,a,data,name,expected=None):
  o=bank*8192+(a&8191)
  if expected is not None:
   expected=bytes.fromhex(expected);assert prg[o:o+len(expected)]==expected,name
  prg[o:o+len(data)]=data;changes.append(dict(bank=bank,cpu=a,size=len(data),name=name))
 def hook(bank,a,label,expected,jsr=False):put(bank,a,bytes([0x20 if jsr else 0x4C,h[label]&255,h[label]>>8]),label,expected)
 put(16,0x8000,(P/'build/code.bin').read_bytes().ljust(8192,b'\0'),'Private code load image')
 put(31,0xFE72,(P/'build/boot.bin').read_bytes(),'MMC3 WRAM loader','FF FF FF')
 put(31,0xFFFC,h['Boot'].to_bytes(2,'little'),'Reset vector','00 C0')
 hook(31,0xF297,'PlayerGate','A5 62 29')
 hook(31,0xFA74,'AttackGate','A5 21 29')
 hook(30,0xC046,'PrepareWait','20 63 C0',True)
 put(30,0xD19B,bytes([0x20,h['SpawnReset']&255,h['SpawnReset']>>8,0xEA]),'Clear private motion at native stage initialization','A2 00 A9 00')
 put(12,0xA0ED,bytes([0x20,h['PlayerSpawnReset']&255,h['PlayerSpawnReset']>>8,0xEA]),'Clear private motion on native checkpoint/life restart','A9 00 85 62')
 hook(11,0xA003,'DrawGate','4C 70 A0')
 hook(30,0xC969,'ContactGate','A5 62 29')
 put(30,0xCCA7,bytes([0x20,h['FireCollision']&255,h['FireCollision']>>8,0xEA,0xEA]),'Mario fireballs share native enemy damage','A6 44 BD 51 06')
 put(31,0xE093,bytes([0x20,h['Palette']&255,h['Palette']>>8,0xEA,0xEA,0xEA]),'Dedicated current-frame player palette','A9 00 85 5F 85 60')
 put(31,0xE09E,bytes([0x20,h['ChrWrite']&255,h['ChrWrite']>>8,0xEA,0xEA]),'Preserve Namcot CHR register masks','B5 13 8D 01 80')
 header=bytearray(old[:16]);header[4]=16;header[5]=16;header[6]=0x40;header[7]=8;header[8]=0;header[10]=7
 rom=bytes(header+prg+chr_new)
 (P/'dist'/f'{NAME}.nes').write_bytes(rom);(P/'dist'/f'{NAME}.ips').write_bytes(ips(old,rom))
 manifest=dict(base_rom=str(BASE),base_sha256=BASE_SHA,smb_sha256=SMB_SHA,output_sha256=sha(rom),mapper=4,prg_kib=256,chr_kib=128,work_ram_kib=8,labels=h,native={},hooks=changes,
  source_method='Exact USA ROM byte hooks, physical PRG-bank tracing and native controller replays',source_revision='smb1base 46ff88f7d9e854db80bf8d50e5bf74340fcc64ce; USE_SMB2J_FEATURES=0',chr_clone_native_banks=[0,1,2,3,24],poses=selected)
 (P/'build/manifest.json').write_text(json.dumps(manifest,indent=2));print(NAME,sha(rom))
if __name__=='__main__':main()
