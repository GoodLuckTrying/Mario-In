"""Source-exact directional packets; native actor tile numbers remain unchanged."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'tools'))
from directional_art import pose,source_info
from atlas import native_tiles,recolor

def tile(p,x,y):
 return bytes(sum(((p[y+dy][x+dx]>>plane)&1)<<(7-dx) for dx in range(8)) for plane in [0,1] for dy in range(8))

def build(old,smb):
 used,poses=native_tiles(old)
 # $3E/$3F/$F7 are native death particles emitted directly from $0603,
 # outside the metasprite tables. $0A-$0D belong to the replaced heads;
 # the original tongue uses $9A-$A1, not those head cells.
 used=set(used)|{0x0E,0x0F,0x3E,0x3F,0x4E,0x4F,0x50,0xEF,0xF7}|set(range(0x22,0x26))
 slots=[t for t in range(256)if t not in used][:33]
 assert len(slots)==33
 packets=[];fixtures=[]
 for power in range(3):
  for view in ['front','front_right','right','back_right','back']:
   for state,step in [('idle',0),('walk',0),('walk',1),('walk',2),('jump',0)]:
    p=pose('small'if power==0 else 'big',view,state,step)
    if power==0:p=[[0]*16 for _ in range(16)]+p
    raw=b''.join(tile(p,x,y)for y in range(0,32,8)for x in [0,8])
    cloth=recolor(raw[:16],[0,3,0,2]if power==2 else[0,2,0,1])
    packet=b''.join(recolor(raw[i:i+16],[0,3,0,2]if power==2 else[0,2,0,1])for i in range(0,128,16))
    packet+=b''.join(recolor(raw[i:i+16],[0,0,2,0])for i in range(0,128,16))
    assert len(packet)==256
    packets.append(packet);fixtures.append([''.join(map(str,row))for row in p])
 (ROOT/'build/directional-packets.chr').write_bytes(b''.join(packets))
 (ROOT/'build/directional-fixtures.lua').write_text('return '+json.dumps(fixtures).replace('[','{').replace(']','}')+'\n')
 fire=smb[0x8010+0x64*16:0x8010+0x65*16]
 lines=[f'FireSlot={slots[32]}','; Generated private slots; every native tile number remains identical.','SpriteSlots: .byte '+','.join(map(str,slots)),'SpriteOamSlots: .byte '+','.join(str(slots[actor*16+(i^flip)])for actor in range(2)for flip in [0,1]for i in range(16)),'FirePattern: .byte '+','.join(map(str,fire))]
 # Exact equality IDs let the NMI skip chunks already resident in the
 # inactive bank (especially blank small-Mario rows and a stationary P2).
 for chunk in range(4):
  unique={};ids=[]
  for packet in packets:
   data=packet[chunk*64:(chunk+1)*64]
   if data not in unique:unique[data]=len(unique)
   ids.append(unique[data])
  lines += [f'FrameChunk{chunk}: .byte '+','.join(map(str,ids))]
 # Leave time for the native terrain transfer, CHR-backed music reads,
 # sprite DMA, and (critically) the final scroll restore before pre-render.
 # A 128-byte transfer met its own deadline but pushed that restore into
 # scanline 0, making the whole playfield jump whenever Mario animated.
 # Four tiles take 560 cycles, including each scattered tile's address.
 lines += ['.segment "UPLOAD"']
 for chunk in range(8):
  lines += [f'UploadChunk{chunk}:']
  for n in range(4):
   logical=chunk*4+n;physical=slots[logical]
   lines += [f' lda #${physical>>4:02X}',' sta $2006',f' lda #${(physical*16)&255:02X}',' sta $2006']
   for i in range(16):lines +=[f' lda $7200+{logical*16+i}',' sta $2007']
  lines += [' rts']
 (ROOT/'src/directional.inc').write_text('\n'.join(lines)+'\n')
 return {'directional_source':source_info(),'used_native_tiles':sorted(used),'private_slots':slots,'native_pose_tiles':poses,'packet_count':75,'packet_bytes':256,'physical_sprite_banks':[8,10],'original_chr_banks':list(range(8)),'upload_bytes_per_nmi':64,'commit_separate_from_upload':True,'canonical_side_views_face':'left'}
