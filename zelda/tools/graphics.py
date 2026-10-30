"""SMB1 sides and exact supplied front/back directional cells."""
from pathlib import Path
import sys,json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'tools'))
from directional_art import pose as directional_pose,source_info
def reference_front():
 # Small Fire Mario at native 16x16 resolution in the supplied CursedMario
 # sheet. Convert its four exact RGB values into NES palette indices.
 return directional_pose('small','front')
FRONT=[''.join(str(c)for c in row)for row in reference_front()]
BACK=[''.join(str(c)for c in row)for row in directional_pose('small','back')]
def decode(data):
 return [[((data[y]>>(7-x))&1)|(((data[y+8]>>(7-x))&1)<<1)for x in range(8)]for y in range(8)]
def encode(p):
 return bytes(sum(((p[y][x]>>bit)&1)<<(7-x)for x in range(8))for bit in [0,1]for y in range(8))
def frame(chr,tiles):
 out=[[0]*16 for _ in range(16)]
 for tile,(ox,oy) in zip(tiles,[(0,0),(8,0),(0,8),(8,8)]):
  p=decode(chr[tile*16:(tile+1)*16])
  for y in range(8):out[oy+y][ox:ox+8]=p[y]
 return out
def pack(p):
 # Native Link uses two 8x16 sprites: left top/bottom, right top/bottom.
 return b''.join(encode([row[x:x+8]for row in p[y:y+8]])for x,y in [(0,0),(0,8),(8,0),(8,8)])

def stride(pose):
 out=[row[:]for row in pose]
 # Lift the rear foot two rows; the front leg stays extended. Mirroring
 # swaps those roles. Raising the opposite arm makes the step readable.
 for y,row in enumerate(['0000111001110000','0000111003330000','0000111000000000','0003333000000000'],12):
  out[y]=[int(c)for c in row]
 for y in range(8,12):out[y][2:4]=pose[y+1][2:4]
 out[12][2:4]=[0,0]
 assert out[:7]==pose[:7]
 return out
def build(source,smb):
 chr=smb[0x8010:];front=[[int(c)for c in row]for row in FRONT];back=[[int(c)for c in row]for row in BACK]
 side=frame(chr,[0x32,0x33,0x34,0x35]);walk=frame(chr,[0x36,0x37,0x38,0x39]);attack=frame(chr,[0x32,0x33,0x44,0x45])
 fa=directional_pose('small','front','throw');ba=directional_pose('small','back','throw');lift=[row[:]for row in front]
 for y in range(3,8):lift[y][1:3]=[2,2];lift[y][13:15]=[2,2]
 lift[8][2:4]=[3,3];lift[8][12:14]=[3,3]
 path=source/'bin/dat/CommonSpritePatterns.dat';patterns=bytearray(path.read_bytes())
 poses=[side,walk,front,back,attack,fa,ba]
 for i,p in enumerate(poses):patterns[i*64:(i+1)*64]=pack(p)
 fire=b''.join(chr[t*16:(t+1)*16]+bytes(16)for t in [0x64,0x65])
 # The renderer no longer uses Link's shield-specific head tiles. Reuse
 # those four tiles, preserving the transparent sprite and all weapon art.
 patterns[0x58*16:0x5c*16]=fire
 front_walk=directional_pose('small','front','walk',0);back_walk=directional_pose('small','back','walk',0)
 fixtures=[]
 for view,art in [('down',front_walk),('up',back_walk)]:
  variants=[]
  for flip in [0,1]:
   rows=[''.join(map(str,row[::-1]if flip else row))for row in art]
   variants.append('['+str(flip)+']={'+','.join(json.dumps(row)for row in rows)+'}')
  fixtures.append(view+'={'+','.join(variants)+'}')
 (ROOT/'build/directional-walk-fixtures.lua').write_text('return {'+','.join(fixtures)+'}\n')
 (ROOT/'build/directional-art.json').write_text(json.dumps(source_info(),indent=2))
 patterns[0x5c*16:0x60*16]=pack(front_walk)
 # These two former magic-shield head pairs are not adjacent, so the
 # renderer explicitly selects each half of the rear walking pose.
 rear=pack(back_walk)
 patterns[0x54*16:0x56*16]=rear[:32]
 patterns[0x60*16:0x62*16]=rear[32:]
 # The lift's right half needs its own tiles: Mario is asymmetric and
 # cannot use Link's mirrored single-half drawing convention.
 patterns[0x56*16:0x58*16]=pack(lift)[32:]
 one_hand=[row[:8]+front[y][8:]for y,row in enumerate(lift)]
 (ROOT/'build/lift-fixtures.lua').write_text('return {'+','.join('{'+','.join(json.dumps(''.join(map(str,row)))for row in art)+'}'for art in [one_hand,lift])+'}\n')
 path.write_bytes(patterns)
 demo=source/'bin/dat/DemoSpritePatterns.dat';data=bytearray(demo.read_bytes())
 # Keep the native lift left half at $78 and preserve the adjacent
 # magic projectile at $7A. The freed shield pair $56 holds its right.
 data[0x80:0xa0]=pack(lift)[:32];demo.write_bytes(data)
 (ROOT/'build/player-patterns.chr').write_bytes(patterns)
 # Mesen's rendered NES shades, including Zelda's sand background.
 palette=[(247,216,165),(255,254,255),(234,158,34),(181,49,32)]
 preview=Image.new('RGB',(8*104,136),palette[0]);d=ImageDraw.Draw(preview)
 for i,(name,p)in enumerate(zip(['RIGHT','WALK','FRONT','BACK','ATTACK','FRONT A','BACK A','LIFT'],poses+[lift])):
  for y,row in enumerate(p):
   for x,c in enumerate(row):d.rectangle((i*104+4+x*6,8+y*6,i*104+9+x*6,13+y*6),fill=palette[c])
  d.text((i*104+6,116),name,fill=(60,32,16))
 preview.save(ROOT/'build/mario-sprites.png')
 walk_preview=Image.new('RGB',(4*104,136),palette[0]);d=ImageDraw.Draw(walk_preview)
 for i,(name,p)in enumerate([('DOWN LEFT',front_walk),('DOWN RIGHT',[row[::-1]for row in front_walk]),('UP LEFT',back_walk),('UP RIGHT',[row[::-1]for row in back_walk])]):
  for y,row in enumerate(p):
   for x,c in enumerate(row):d.rectangle((i*104+4+x*6,8+y*6,i*104+9+x*6,13+y*6),fill=palette[c])
  d.text((i*104+6,116),name,fill=(60,32,16))
 walk_preview.save(ROOT/'build/walking-sprites.png')
