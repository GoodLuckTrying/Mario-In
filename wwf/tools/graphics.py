from pathlib import Path
import importlib.util,sys,shutil,json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT.parent
sys.path.insert(0,str(BASE/'tools'))
from directional_art import pose as directional_pose,source_info
def build(smb):
 spec=importlib.util.spec_from_file_location('assets',BASE/'tools/build.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a);a.ROOT=ROOT;a.graphics(smb)
 sys.path.insert(0,str(BASE/'kungfu/tools'))
 from melee_art import build as melee,unpack
 raw=(ROOT/'build/mario-frames.chr').read_bytes();m=melee(raw)
 def body(n):return unpack(raw[n*128:(n+1)*128])
 poses=[body(24),body(0),body(1),body(2),unpack12(m[5]),unpack12(m[3]),body(4),body(10),unpack12(m[29]),body(4)]
 # A knocked-down wrestler lies on the mat; native recovery/pins still run.
 p=Image.new('L',(24,32));p.putdata([v for row in body(24)for v in row]);p=p.rotate(90,expand=True)
 down=Image.new('L',(24,32));p=p.resize((24,12),Image.Resampling.NEAREST);down.paste(p,(0,20))
 poses.append([[down.getpixel((x,y))for x in range(24)]for y in range(32)])
 (ROOT/'assets').mkdir(exist_ok=True)
 ref=ROOT/'assets/front-reference.png'
 if not ref.exists():shutil.copyfile(BASE/'zelda/assets/front-reference.png',ref)
 for view in ['front','back']:
  for state,step in [('idle',0),('walk',0),('walk',1)]:
   poses.append([row+[0]*8 for row in directional_pose('big',view,state,step)])
 for view in ['front_right','back_right']:
  for state in ['idle','walk']:poses.append([row+[0]*8 for row in directional_pose('big',view,state)])
 # All body poses live in the human's native 20-tile upload packet.
 # $83..$C2 are deformable rope/background patterns, not spare CHR.
 maps=[];stream=bytearray()
 fire=b''.join(smb[0x8010+t*16:0x8020+t*16]for t in [0x64,0x65])
 for pixels in poses:
  for cell,(ty,tx)in enumerate((y,x)for y in range(0,32,8)for x in range(0,24,8)):
   data=bytes(sum(((pixels[ty+y][tx+x]>>bit)&1)<<(7-x)for x in range(8))for bit in range(2)for y in range(8))
   stream+=data;maps.append(cell if any(data)else 255)
  stream+=fire
 (ROOT/'build/pose-map.bin').write_bytes(bytes(maps))
 (ROOT/'build/pose-attrs.bin').write_bytes(bytes(len(maps)))
 (ROOT/'build/pose-masks.bin').write_bytes(bytes(0 if t==255 else 1 for t in maps))
 (ROOT/'build/streamed-poses.chr').write_bytes(stream)
 (ROOT/'build/directional-fixtures.lua').write_text('return {'+','.join('{'+','.join(json.dumps(''.join(map(str,row)))for row in art)+'}'for art in poses)+'}\n')
 (ROOT/'src/art.inc').write_text(f'FIRE0=12\nFIRE1=13\nPOSE_COUNT={len(poses)}\n')
 colors=[(0,0,0),(255,254,255),(234,158,34),(181,49,32)]
 preview=Image.new('RGB',(len(poses)*96,144));dr=ImageDraw.Draw(preview)
 for i,pixels in enumerate(poses):
  im=Image.new('RGB',(24,32));im.putdata([colors[v]for row in pixels for v in row]);preview.paste(im.resize((96,128),Image.Resampling.NEAREST),(i*96,0));dr.text((i*96,130),str(i),fill='white')
 preview.save(ROOT/'build/poses.png')
 portrait=Image.new('L',(48,48));portrait.putdata([3 if x in(0,47)or y in(0,47)else 0 for y in range(48)for x in range(48)])
 for y in range(32):
  for x in range(24):portrait.putpixel((12+x,8+y),poses[0][y][x])
 data=bytes(sum(((portrait.getpixel((tx+x,ty+y))>>b)&1)<<(7-x)for x in range(8))for ty in range(0,48,8)for tx in range(0,48,8)for b in range(2)for y in range(8))
 (ROOT/'build/portrait.chr').write_bytes(data)
 return {'native_static_chr_preserved_through':'$1C2F','poses':['idle','walk1','walk2','walk3','punch','kick','air','crouch','guard/grapple','climb/win','down','front','front-step1','front-step2','back','back-step1','back-step2','front-diagonal','front-diagonal-step','back-diagonal','back-diagonal-step'],'source':'SMB1 side and existing Kung Fu melee art; all poses and fireballs through the native CHR streamer','directional_source':source_info(),'streamed_pose_bytes':len(stream),'packet_bytes':224,'work_ram_kib':8}
def unpack12(data):
 p=[[0]*24 for _ in range(32)]
 for tile,(tx,ty)in enumerate([(x,y)for y in range(0,32,8)for x in [0,8]]+[(16,y)for y in range(0,32,8)]):
  d=data[tile*16:tile*16+16]
  for y in range(8):
   for x in range(8):p[ty+y][tx+x]=(d[y]>>(7-x)&1)|((d[y+8]>>(7-x)&1)*2)
 return p
