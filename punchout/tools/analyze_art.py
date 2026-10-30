from pathlib import Path
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'punchout'; B=(P/'build/reference/PRG_Bank00B.bin').read_bytes()
ROM=Path("C:/nes/Mike Tyson's Punch-Out!! (Japan, USA) (En) (Rev 1).nes").read_bytes()
CHR=ROM[16+0x20000:]
def byte(a):return B[a-0x8000]
def word(a):return byte(a)+byte(a+1)*256
def frame(n):
    table=0x8800+n*2 if n<128 else 0x88c4+(n&127)*2
    s=word(table); start=word(0x8a3f+byte(s)); ptr=word(s+1)
    a=start; writes=[]; steps=0;control=False
    while True:
        steps+=1;assert steps<2048
        t=byte(ptr);ptr+=1
        if not control and t:
            writes.append((a,t));a+=32;continue
        if not control:
            control=True;continue
        if t==0xfd:return dict(id=n,start=start,chr=byte(ptr),writes=writes)
        if t==0xfe:
            count=byte(ptr);value=byte(ptr+1);ptr+=2
            for j in range(count):writes.append((a,(value+j)&255));a+=32
            control=False
        else:
            start+=1;a=start
            if t:
                writes.append((a,t));a+=32;control=False
            # A zero after a column advance immediately introduces another
            # control command (native $8111 jumps to $8074, not $8030).
def tile(c,t):
    b=CHR[c*4096+t*16:c*4096+t*16+16]
    return [[((b[y]>>(7-x))&1)+2*((b[y+8]>>(7-x))&1) for x in range(8)]for y in range(8)]
def main():
    allf=[frame(n) for n in list(range(98))+list(range(128,175))]
    # Native palette roles, shown independently from the scrolling ring.
    colors=[(25,25,38),(0,0,0),(255,183,174),(255,255,255)]
    im=Image.new('RGB',(10*100,15*142),(80,80,80));d=ImageDraw.Draw(im)
    for k,f in enumerate(allf):
        ws=[(a,t) for a,t in f['writes'] if t not in (0xff,0xfd,0xfe)]
        if not ws:continue
        x0=min(a%32 for a,t in ws);y0=min((a&1023)//32 for a,t in ws)
        x1=max(a%32 for a,t in ws);y1=max((a&1023)//32 for a,t in ws)
        f['bbox']=[x0,y0,x1,y1]
        ox=(k%10)*100;oy=(k//10)*142
        d.text((ox+2,oy+2),f"{f['id']:02X} chr {f['chr']}",fill='white')
        for a,t in f['writes']:
            if t==255:continue
            for y,row in enumerate(tile(f['chr'],t)):
                for x,v in enumerate(row):
                    if v:
                        xx=ox+(a%32-x0)*8+x;yy=oy+18+((a&1023)//32-y0)*8+y
                        if 0<=xx<im.width and 0<=yy<im.height:im.putpixel((xx,yy),colors[v])
    im.save(P/'build/native-poses.png');(P/'build/native-frames.json').write_text(json.dumps(allf,indent=2))
    for c in range(32):
        im=Image.new('RGB',(128,128))
        for t in range(256):
            for y,row in enumerate(tile(c,t)):
                for x,v in enumerate(row):im.putpixel(((t%16)*8+x,(t//16)*8+y),colors[v])
        im.resize((384,384),Image.Resampling.NEAREST).save(P/f'build/chr-{c:02}.png')
    print('frames',len(allf),'banks',sorted(set(f['chr'] for f in allf)))
if __name__=='__main__':main()
