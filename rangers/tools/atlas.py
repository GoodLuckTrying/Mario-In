from research import rom,ROOT
from PIL import Image,ImageDraw
chr=rom[16+128*1024:]
out=Image.new('RGB',(256*4,144*8))
d=ImageDraw.Draw(out)
colors=[(12,12,12),(220,90,80),(230,190,130),(250,250,250)]
for bank in range(32):
 bx=bank%4*256;by=bank//4*144
 d.text((bx,by),str(bank),fill='white')
 for t in range(256):
  for y in range(8):
   a,b=chr[bank*4096+t*16+y],chr[bank*4096+t*16+8+y]
   for x in range(8):
    col=((a>>(7-x))&1)|(((b>>(7-x))&1)<<1)
    out.putpixel((bx+t%32*8+x,by+16+t//32*8+y),colors[col])
out.save(ROOT/'build/chr.png')
