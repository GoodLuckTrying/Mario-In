from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import *
from build_port_references import ensure_reference
from directional_art import pose,source_info
P=ROOT/'metroid';NAME='Mario in Metroid';BASE=Path('C:/nes/Metroid (USA).nes')
BASE_SHA='88ad02b0b53012712f3c773a62073847551cec191aeda5d3ec19b22b594640eb'
def main():
 for d in ('build','dist','tests'):(P/d).mkdir(parents=True,exist_ok=True)
 old=BASE.read_bytes();assert sha(old)==BASE_SHA
 ensure_reference('metroid')
 sym=(ROOT/'build/metroid-reference/metroid-reference.sym').read_text()
 entries=[(int(b,16),int(a,16),k) for b,a,k in re.findall(r'^(\w\w):([\da-fA-F]{4}) (\S+)$',sym,re.M)]
 native={k.replace('@','_').replace('.','_'):a for b,a,k in entries}
 for a,k in re.findall(r'^([\da-fA-F]{8}) (\S+)$',sym,re.M):
  v=int(a,16)
  if v<=65535:native[k.replace('@','_').replace('.','_')]=v
 native={k:v for k,v in native.items() if re.match(r'^\w+$',k)}
 (P/'src/native.inc').write_text('\n'.join(f'N_{k}=${v:04X}' for k,v in native.items()))
 # Protect every shared non-Samus metasprite tile, including elevators and missiles.
 reserved={0,4,0x14,0x24,0x28,0x30,0x38,0x5E,0x5F,0x70,0x71}
 for bank,a,k in entries:
  if bank!=1 or not k.startswith('ObjFrame_') or 'Samus' in k:continue
  pos=16+bank*16384+a-0x8000+3
  for i in range(100):
   t=old[pos];pos+=1
   if t==255:break
   if t==253:pos+=1
   elif t==252:pos+=2
   elif t<252:reserved.add(t)
 available=[i for i in range(0x7B) if i not in reserved]
 print('Dedicated Samus CHR slots',len(available))
 # Keep front at pose 13 and throwing at 14 for the renderer's fixed table.
 atlas=mario_atlas(P,available,selected=[0,1,2,24,4,3,12,13,14,23,16,15,22],extra=[pose('big','front')])
 # Append an original SMB throwing row without moving the front pose.
 original_art=(P/'build/source-art/mario-frames.chr').read_bytes()[11*128:12*128]
 existing={data:tile for tile,data in atlas.items()}
 free=iter(tile for tile in available if tile not in atlas)
 throw=[]
 for i in range(8):
  data=original_art[i*16:i*16+16]
  if data not in existing:
   tile=next(free);atlas[tile]=data;existing[data]=tile
  throw.append(existing[data])
 art=(P/'src/art.inc').read_text();art=art.replace('FireTiles:', ' .byte '+','.join(f'${t:02X}' for t in throw)+'\nFireTiles:');(P/'src/art.inc').write_text(art)
 h=assemble(P)
 new=old[:16]+old[16:]+b'\xFF'*(8*16384)
 patch=Patcher(new,15);patch.rom[4]=16
 patch.put(15,0xC000,old[16+7*16384:],'Native engine duplicated into expanded fixed bank')
 a=(P/'build/code-a.bin').read_bytes();b=(P/'build/code-b.bin').read_bytes()
 # The page-copy loader crosses $77F0-$77FF, which belong to native Metroid
 # latches/repel parameters. Preserve their original cleared startup values.
 patch.put(8,0x8000,a.ljust(1024,b'\x00')+b,'Private RAM code load image')
 boot=(P/'build/boot.bin').read_bytes();assert len(boot)<=0x4F
 patch.put(15,0xC06D,boot,'One-time private RAM loader',old[16+7*16384+0x6D:16+7*16384+0x6D+len(boot)])
 def hook(key,target,jsr=False,offset=0):
  addr=native[key]+offset;o=16+7*16384+addr-0xC000
  patch.hook(15,addr,h[target],target,old[o:o+3],jsr)
 assert old[16+7*16384+native['UpdateSamus']-0xC000+7]==0x20
 hook('UpdateSamus','BeforeHandler',True,7)
 hook('NMI','NmiEnter')
 off=16+7*16384+native['NMI']-0xC000
 tail=old[off:off+60].index(bytes.fromhex('68 A8 68 AA 68 28 40'))
 hook('NMI','NmiLeave',False,tail)
 hook('HorzAccelerate','Horizontal')
 hook('VertAccelerate','Vertical')
 # The landing-specific call, rather than every native StopVertMovement call.
 off=16+7*16384+0x230e
 assert old[off:off+3]==bytes([0x20,native['StopVertMovement']&255,native['StopVertMovement']>>8])
 patch.hook(15,0xE30E,h['Land'],'Landing resets SMB fractions',old[off:off+3],True)
 hook('SamusMoveVertically_loop_up','Ceiling',True)
 addr=native['CheckStopHorzMvmt'];off=16+7*16384+addr-0xC000
 assert old[off+2:off+6]==bytes([0xA9,1,0x85,native['ObjectCounter']])
 hook('CheckStopHorzMvmt','WallGate')
 hook('LDEDE','DrawGate')
 hook('CollisionDetectionEnemy_ReactToCollisionWithSamus','ContactGate')
 hook('CollisionDetectionMellow_ReactToCollisionWithSamus','MellowContactGate')
 # Native projectile hit detection still owns enemies, doors, statues and blastable blocks.
 # Native beams, Ice/Wave and missiles remain completely native.
 def call_hook(start,target,replacement,span=120):
  addr=native[start];off=16+7*16384+addr-0xC000
  i=old[off:off+span].index(bytes([0x20,native[target]&255,native[target]>>8]))
  hook(start,replacement,True,i)
 call_hook('UpdateWorld','UpdateSamusProjectiles','Projectiles')
 call_hook('CollisionDetection_exitLoop_Door','GetEnemyXSlotPosition','EnemyFireCheck')
 call_hook('CollisionDetection','GetMellowXSlotPosition','MellowFireCheck',200)
 # Fired projectile initialization tail resets its private arc state on slot reuse.
 addr=native['InitBullet'];off=16+7*16384+addr-0xC000
 assert old[off:off+5]==bytes.fromhex('98 AA FE 00 03')
 patch.put(15,addr,bytes([0x20,h['FireInit']&255,h['FireInit']>>8,0xEA,0xEA]),'Reset fireball arc when a projectile slot is reused',old[off:off+5])
 for tile,data in atlas.items():patch.put(6,0x8000+tile*16,data,'SMB Mario CHR')
 # Rewrite only sprite palette 0 in each area's explicit palette strings.
 palette_changes=0
 for bank,a,k in entries:
  if bank not in range(1,6) or not k.startswith('Palette'):continue
  offset=16+bank*16384+a-0x8000
  if '@' in k:continue
  if old[offset:offset+3]==b'\x3F\x12\x02':
   patch.put(bank,a+3,bytes([0x27,0x16]),'Keep Fire Mario colors when selecting native equipment');palette_changes+=1
  if old[offset:offset+3]==b'\x3F\x11\x03':
   patch.put(bank,a+3,bytes([0x30,0x27,0x16]),'Fire Mario suit/equipment palette');palette_changes+=1
  if old[offset:offset+3]==b'\x3F\x10\x04':
   patch.put(bank,a+4,bytes([0x30,0x27,0x16]),'Fire Mario palette');palette_changes+=1
  if old[offset:offset+3]==b'\x3F\x00\x20':
   patch.put(bank,a+3+17,bytes([0x30,0x27,0x16]),'Fire Mario room-initialization palette');palette_changes+=1
 rom=bytes(patch.rom)
 (P/'dist'/f'{NAME}.nes').write_bytes(rom);(P/'dist'/f'{NAME}.ips').write_bytes(ips(old,rom))
 manifest=dict(base_rom=str(BASE),base_sha256=BASE_SHA,smb_sha256=SMB_SHA,output_sha256=sha(rom),mapper=1,prg_kib=256,
  upstream='https://github.com/metroidret/m1disasm',source_revision='efbd348d7251463d6179775fc6e901207d210610',
  labels=h,native=native,hooks=patch.changes,atlas_tiles=len(atlas),protected_tiles=sorted(reserved),palette_strings=palette_changes,directional_source=source_info())
 (P/'build/manifest.json').write_text(json.dumps(manifest,indent=2));print(NAME,sha(rom))
if __name__=='__main__':main()
