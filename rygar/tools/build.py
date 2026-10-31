"""Native Rygar integration, bound to the USA ROM's checked hook bytes."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import *
P=ROOT/'rygar';NAME='Mario in Rygar';BASE=Path('C:/nes/Rygar (USA).nes')
BASE_SHA='965330fed9f5b8492452f3b53084752e83b7f899a1f88f3c475ece2fde6f9231'
def main():
 for d in ('build','dist'):(P/d).mkdir(exist_ok=True)
 old=BASE.read_bytes();assert sha(old)==BASE_SHA
 from build import graphics
 smb=SMB.read_bytes();assert sha(smb)==SMB_SHA
 graphics(smb,output_dir=P/'build/source-art')
 frames=(P/'build/source-art/mario-frames.chr').read_bytes()
 selected=[0,1,2,24,4,10]
 pool=iter(range(0x10,0x46,2));used={};atlas={};tables=[]
 for pose in selected:
  f=frames[pose*128:(pose+1)*128];row=[]
  for y in range(2):
   for x in range(2):
    pair=f[(y*4+x)*16:(y*4+x+1)*16]+f[(y*4+x+2)*16:(y*4+x+3)*16]
    if pair not in used:
     tile=next(pool);used[pair]=tile;atlas[tile]=pair
    row.append(used[pair])
  tables.extend(row)
 fire=[]
 for tile in [0x64,0x65]:
  index=next(pool);atlas[index]=smb[0x8010+tile*16:0x8010+(tile+1)*16]+bytes(16);fire.append(index)
 (P/'src/art.inc').write_text('MarioTiles:\n'+''.join(' .byte '+','.join(f'${v:02X}'for v in tables[i:i+4])+'\n'for i in range(0,len(tables),4))+'FireTiles: .byte '+','.join(f'${v:02X}'for v in fire)+'\n',newline='\n')
 from directional_art import pose,source_info
 dynamic=bytearray()
 def encode(pixels):
  planar=bytes(sum(((pixels[cy*8+y][cx*8+x]>>pl)&1)<<(7-x)for x in range(8))for cy in range(4)for cx in range(2)for pl in range(2)for y in range(8))
  return b''.join(planar[(y*4+x)*16:(y*4+x+1)*16]+planar[(y*4+x+2)*16:(y*4+x+3)*16]for y in range(2)for x in range(2))
 for view in ['front','front_right','right','back_right','back']:
  dynamic.extend(encode(pose('big',view)))
  for step in range(3):dynamic.extend(encode(pose('big',view,'walk',step)))
 for index in [8,9,22,3]:
  f=frames[index*128:(index+1)*128]
  dynamic.extend(b''.join(f[(y*4+x)*16:(y*4+x+1)*16]+f[(y*4+x+2)*16:(y*4+x+3)*16]for y in range(2)for x in range(2)))
 (P/'build/directional-frames.bin').write_bytes(dynamic)
 h=assemble(P)
 patch=Patcher(old+b'\xFF'*131072,15);patch.rom[4]=16;patch.rom[10]=7
 patch.put(15,0xC000,old[-16384:],'Native engine copied to expanded fixed bank')
 image=(P/'build/code.bin').read_bytes()+(P/'build/directional.bin').read_bytes()
 patch.put(8,0x8000,image.ljust(8192,b'\0'),'Private WRAM load image')
 assert old[-16384+0x1EB2:-16384+0x2000]==bytes(0x14E)
 patch.put(15,0xDEB2,(P/'build/boot.bin').read_bytes(),'Conflict-safe private code loader',bytes(0x14E))
 patch.hook(15,0xC000,h['Boot'],'Reset loads private work RAM','78 D8 A9')
 patch.put(6,0x8500,bytes([0x20,h['SpawnReset']&255,h['SpawnReset']>>8,0xEA]),'Clear private state at native player initialization','A9 00 85 18')
 patch.hook(5,0xA407,h['Calculate'],'Player-only SMB prediction before native collision','20 2B 96',True)
 patch.hook(5,0x9BC1,h['BeginStep'],'SMB prediction feeds native terrain probes','20 2B 96',True)
 patch.hook(5,0x9C78,h['BeginOverhead'],'Native overhead tools alongside fireballs','20 2B 96',True)
 patch.hook(5,0x9C0A,h['Response'],'Reset Mario motion at native terrain contact','20 EB A3',True)
 patch.put(5,0xADDF,bytes([0x4C,h['StompBounce']&255,h['StompBounce']>>8,0xEA,0xEA]),'Native stomp updates private Mario bounce','A9 84 8D C2 04')
 patch.put(5,0xADC9,bytes([10]),'Native stomp overlap forgiveness','03')
 patch.hook(5,0xADFA,h['ContactDamage'],'Short protection after native stomp','20 01 AE',True)
 patch.hook(15,0xC14A,h['FinishFrame'],'Prepare Mario OAM after native logic, outside vblank','20 00 80',True)
 patch.hook(15,0xC117,h['Palette'],'Fire palette during native vblank','AD 02 20',True)
 for tile,pair in atlas.items():
  patch.put(0,0x8000+tile*16,pair,'Retired side-view player CHR pair')
  if tile in fire:patch.put(2,0x8800+tile*16,pair,'Overhead fireball CHR pair')
 # Native overhead Diskarmor frames use $0A/$12/$1E/$26. Leave those and
 # all enemy patterns intact; $30..$3F belong to retired player poses only.
 for tile in [0x30,0x38]:
  patch.put(2,0x8800+tile*16,dynamic[:128],'Preloaded complete overhead front-pose buffer')
 rom=bytes(patch.rom);(P/'dist'/f'{NAME}.nes').write_bytes(rom);(P/'dist'/f'{NAME}.ips').write_bytes(ips(old,rom))
 manifest=dict(base_rom=str(BASE),base_sha256=BASE_SHA,smb_sha256=SMB_SHA,output_sha256=sha(rom),mapper=2,submapper=2,prg_kib=256,work_ram_kib=8,labels=h,native={},hooks=patch.changes,poses=selected,player_chr_pairs=sorted(atlas),protected_chr_start=0x460,
  source_method='Exact USA byte hooks and physical-bank/native-controller traces',source_revision='smb1base 46ff88f7d9e854db80bf8d50e5bf74340fcc64ce; USE_SMB2J_FEATURES=0',directional_source=source_info(),directional_buffers=[0,8],overhead_directional_buffers=[0x30,0x38])
 (P/'build/manifest.json').write_text(json.dumps(manifest,indent=2));print(NAME,sha(rom))
if __name__=='__main__':main()
