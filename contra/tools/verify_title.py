"""Independent ROM pixel reconstruction of the supplied title and blinks."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageSequence
from title_assets import RGB,NES
ROOT=Path(__file__).resolve().parents[1]
r=(ROOT/'dist/Mario and Luigi in Contra.nes').read_bytes()
a=16+8*16384
d=r[16+10*16384:16+11*16384];assert d[0]==10
chr=d[1:8193];nt=d[8193:9217];pal=d[9217:9249];oam=d[9249:9505]
def pixel(at,x,y):return((chr[at+y]>>(7-x))&1)|(((chr[at+8+y]>>(7-x))&1)<<1)
def draw(nt,oam):
 result=[]
 for y in range(240):
  row=[]
  for x in range(256):
   t=nt[y//8*32+x//8];attr=nt[960+y//32*8+x//32];pi=(attr>>((y%32//16)*4+(x%32//16)*2))&3
   v=pixel((0 if y<128 else 4096)+t*16,x%8,y%8)
   row.append(pal[pi*4+v])
  result.append(row)
 for i in reversed(range(0,256,4)):
  sy,t,attr,sx=oam[i:i+4];sy+=1
  if sy>=240:continue
  for dy in range(16):
   if sy+dy>=240:continue
   for dx in range(8):
    if sx+dx>=256:continue
    px=7-dx if attr&64 else dx;py=15-dy if attr&128 else dy
    v=pixel((t&1)*4096+(t&254)*16+(py//8)*16,px,py%8)
    if v:result[sy+dy][sx+dx]=pal[16+(attr&3)*4+v]
 return result
source=Image.open(ROOT/'assets/title-screen.png').convert('RGB')
assert hashlib.sha256((ROOT/'assets/title-screen.png').read_bytes()).hexdigest()=='4056eb98da03901232d1e727a88f17b7e775276c240444b3f941f43192a8fe90'
reference=ROOT/'assets/title-blink-reference.gif'
assert hashlib.sha256(reference.read_bytes()).hexdigest()=='467e275d1985455d5cd8a1dbd352a2a3147a07b5e98f58ededf977023804ffb3'
gif=[f.convert('RGB').copy()for f in ImageSequence.Iterator(Image.open(reference))]
labels=json.loads((ROOT/'build/manifest.json').read_text())['labels']
def animate(player,state,nt,oam):
 index=player*3+state
 pointer=d[labels['TitleBlinkLo']-0x8000+index]|(d[labels['TitleBlinkHi']-0x8000+index]<<8)
 cursor=pointer-0x8000;length=d[cursor];cursor+=1;end=cursor+length
 while cursor<end:
  assert d[cursor]==1
  address=(d[cursor+1]<<8)|d[cursor+2];cursor+=3
  while d[cursor]!=255:
   assert 0x21e0<=address<0x2280,'blinking may change only the face nametable rows'
   nt[address-0x2000]=d[cursor];address+=1;cursor+=1
  cursor+=1
 assert cursor==end
 count=d[cursor];cursor+=1
 for _ in range(count):
  slot,tile,attr=d[cursor:cursor+3];cursor+=3
  assert slot>=8 and slot%4==0,'preserve sprite zero and selection cursor'
  oam[slot+1:slot+3]=[tile,attr]
for mario in range(3):
 for luigi in range(3):
  frame=source.copy();new_nt=bytearray(nt);new_oam=bytearray(oam)
  for player,state in enumerate([mario,luigi]):
   animate(player,state,new_nt,new_oam)
   if state:
    for y in range(115,151):
     for x in range(140 if player==0 else 198,194 if player==0 else 242):
      if gif[state].getpixel((x,y))!=gif[0].getpixel((x,y)):frame.putpixel((x+6,y-2),gif[state].getpixel((x,y)))
  result=draw(new_nt,new_oam)
  for y in range(240):
   for x in range(256):assert result[y][x]==NES[RGB.index(frame.getpixel((x,y)))],(mario,luigi,x,y)
for line in range(240):
 cells=sum(oam[i]+1<=line<oam[i]+17 for i in range(0,256,4))
 assert cells<=8,(line,cells)
print('PASS all 9 independent blink combinations (552960 pixels), assembled ROM tile/OAM commands, exact supplied title/GIF colors, <=8 sprites/scanline')
