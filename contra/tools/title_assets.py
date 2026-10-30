"""Exact NES tile/sprite decomposition of the supplied title artwork."""
from pathlib import Path
from collections import Counter
import hashlib,json
from PIL import Image,ImageSequence
ROOT=Path(__file__).resolve().parents[1]
BG=[(1,2,8),(1,7,10),(2,3,6),(3,4,5)]
SP=[(2,4,9),(2,4,6),(1,7,10),(3,4,5)]
RGB=[(0,0,0),(173,173,173),(255,255,255),(249,231,181),(152,55,0),(0,19,128),(34,119,0),(188,190,0),(183,30,123),(181,49,32),(228,229,148)]
NES=[15,16,32,55,23,1,25,40,21,22,56]
def encode(p):return bytes(sum(((p[y][x]>>plane)&1)<<(7-x)for x in range(8))for plane in [0,1]for y in range(8))
def blink_sources(src):
 reference=ROOT/'assets/title-blink-reference.gif'
 assert hashlib.sha256(reference.read_bytes()).hexdigest()=='467e275d1985455d5cd8a1dbd352a2a3147a07b5e98f58ededf977023804ffb3'
 gif=[frame.convert('RGB').copy()for frame in ImageSequence.Iterator(Image.open(reference))]
 assert [f.size for f in gif]==[(256,240)]*6
 variants=[src]
 # The GIF moves both illustrations six pixels left and two down relative
 # to the installed title. Borrow only changed eye pixels, preserving all
 # other supplied title art, lettering and placement.
 for left,right in [(140,194),(198,242)]:
  for state in [1,2]:
   frame=[r[:]for r in src]
   for y in range(115,151):
    for x in range(left,right):
     if gif[state].getpixel((x,y))!=gif[0].getpixel((x,y)):
      frame[y-2][x+6]=RGB.index(gif[state].getpixel((x,y)))
   variants.append(frame)
 return variants


def build():
 path=ROOT/'assets/title-screen.png';pic=Image.open(path).convert('RGB');assert pic.size==(256,240)
 assert set(pic.getdata())==set(RGB)
 src=[[RGB.index(pic.getpixel((x,y)))for x in range(256)]for y in range(240)]
 # Store the supplied mushroom cursor as a movable OAM cell.
 cursor=[[src[y][x]for x in range(16,24)]for y in range(152,168)]
 image=[r[:]for r in src]
 for y in range(150,162):
  for x in range(12,26):image[y][x]=0
 sources=blink_sources(src)
 images=[]
 for frame in sources:
  frame=[r[:]for r in frame]
  for y in range(150,162):
   for x in range(12,26):frame[y][x]=0
  images.append(frame)
 backgrounds=[[[0]*256 for _ in range(240)]for _ in images]
 residuals=[[[0]*256 for _ in range(240)]for _ in images]
 attrs=[0]*64;selected={}
 for yy in range(0,240,16):
  for xx in range(0,256,16):
   def cost(pi):
    cells=0;count=0
    for half in range(2):
     colors={im[y][x]for im in images for y in range(yy,yy+16)for x in range(xx+half*8,xx+half*8+8)}-{0}-set(BG[pi])
     if colors and not any(colors<=set(p)for p in SP):return 100000
     cells+=bool(colors)
    for im in images:
     count+=sum(im[y][x]!=0 and im[y][x]not in BG[pi]for y in range(yy,yy+16)for x in range(xx,xx+16))
    return cells*100+count/len(images)/100
   pi=min(range(4),key=cost);assert cost(pi)<100000
   selected[xx,yy]=pi
   ai=(yy//32)*8+xx//32;shift=(yy%32)//16*4+(xx%32)//16*2;attrs[ai]|=pi<<shift
   for im,bg,res in zip(images,backgrounds,residuals):
    for y in range(yy,yy+16):
     for x in range(xx,xx+16):
      c=im[y][x]
      if c and c in BG[pi]:bg[y][x]=BG[pi].index(c)+1
      else:res[y][x]=c
 patterns=[[bytes(16)],[bytes(16)]];nametables=[]
 for bg in backgrounds:
  nt=[]
  for yy in range(0,240,8):
   bank=0 if yy<128 else 1
   for xx in range(0,256,8):
    t=encode([r[xx:xx+8]for r in bg[yy:yy+8]])
    if t not in patterns[bank]:patterns[bank].append(t)
    nt.append(patterns[bank].index(t))
  nametables.append(bytes(nt+attrs))
 background_counts=list(map(len,patterns))
 assert max(background_counts)<=256,background_counts
 # Sprite pairs can use either pattern table, so extra eye variants do not
 # steal native sprites or exceed a scanline's eight-sprite allowance.
 for bank in range(2):
  if len(patterns[bank])&1:patterns[bank].append(bytes(16))
 pairs={};oams=[[]for _ in images]
 def sprite_tile(pixels,pi):
  pair=b''.join(encode([[0 if c==0 else SP[pi].index(c)+1 for c in r]for r in pixels[row:row+8]])for row in [0,8])
  if pair not in pairs:
   bank=next(b for b in [1,0]if len(patterns[b])<=254)
   slot=len(patterns[bank]);patterns[bank]+=[pair[:16],pair[16:]]
   pairs[pair]=slot|bank
  return pairs[pair]
 def add_sprites(x,y,pixels_list,pis):
  for oam,pixels,pi in zip(oams,pixels_list,pis):oam.extend([y-1,sprite_tile(pixels,pi),pi,x])
 marker_x=next(x for x in range(1,255)if image[127][x]in SP[0] and backgrounds[0][127][x])
 marker=[[0]*8 for _ in range(16)];marker[15][0]=image[127][marker_x]
 add_sprites(marker_x,112,[marker]*len(images),[0]*len(images))
 add_sprites(16,152,[cursor]*len(images),[3]*len(images))
 row_count=Counter()
 for yy in range(0,240,16):
  for xx in range(0,256,8):
   variants=[r[yy:yy+16]for r in residuals]
   pixels_list=[[r[xx:xx+8]for r in res]for res in variants]
   colors=set(c for pixels in pixels_list for r in pixels for c in r)-{0}
   if not colors:continue
   pi=next(i for i,p in enumerate(SP)if colors<=set(p))
   add_sprites(xx,yy,pixels_list,[pi]*len(images));row_count[yy]+=1
 for yy,n in row_count.items():assert n+(1 if yy<168 and yy+16>152 else 0)<=8,(yy,n)
 for oam in oams:
  assert len(oam)<=256
  oam+=([248,0,0,0]*64)[:256-len(oam)]
 chr=b''.join(b''.join(p).ljust(4096,b'\0')for p in patterns)
 pal=bytes(NES[c]for colors in BG+SP for c in(0,)+colors)
 nt=nametables[0];oam=oams[0]
 data=bytes([10])+chr+nt+pal+bytes(oam)
 (ROOT/'build/title-assets.bin').write_bytes(data)
 # Tables contain small native nametable commands and OAM tile changes.
 lines=[];animations=[]
 for who,variants in enumerate([[0,1,2],[0,3,4]]):
  changed=sorted(set(i for variant in variants for i in range(960)if nametables[variant][i]!=nt[i]))
  slots=sorted(set(i for variant in variants for i in range(0,256,4)if oams[variant][i+1:i+3]!=oam[i+1:i+3]))
  for state,variant in enumerate(variants):
   command=[];i=0
   while i<len(changed):
    first=changed[i];last=first;i+=1
    while i<len(changed)and changed[i]//32==first//32:
     last=changed[i];i+=1
    address=0x2000+first
    command += [1,address>>8,address&255]+list(nametables[variant][first:last+1])+[255]
   updates=[b for slot in slots for b in [slot,oams[variant][slot+1],oams[variant][slot+2]]]
   record=bytes([len(command)]+command+[len(updates)//3]+updates)
   label=f'TitleBlink{who}_{state}'
   animations.append({'player':who,'state':state,'label':label,'record':list(record),'background_tiles':len(changed),'sprite_slots':slots})
   lines.append(label+': .byte '+','.join(map(str,record)))
 labels=[a['label']for a in animations]
 lines=['TitleBlinkLo: .byte '+','.join('<'+label for label in labels),'TitleBlinkHi: .byte '+','.join('>'+label for label in labels)]+lines
 (ROOT/'build/title-blink.inc').write_text('\n'.join(lines)+'\n')
 # Reconstruct each complete frame, including transparent eye changes.
 def decode(at,x,y):return((chr[at+y]>>(7-x))&1)|(((chr[at+8+y]>>(7-x))&1)<<1)
 for variant,(nt,oam,src)in enumerate(zip(nametables,oams,sources)):
  actual=[[0]*256 for _ in range(240)]
  for y in range(240):
   for x in range(256):
    pi=selected[x//16*16,y//16*16];tile=nt[(y//8)*32+x//8]
    v=decode((0 if y<128 else 4096)+tile*16,x%8,y%8)
    actual[y][x]=BG[pi][v-1]if v else 0
  for i in reversed(range(0,256,4)):
   y,t,pi,x=oam[i:i+4];y+=1
   if y>=240:continue
   for dy in range(16):
    for dx in range(8):
     v=decode((t&1)*4096+(t&254)*16+(dy//8)*16,dx,dy%8)
     if v:actual[y+dy][x+dx]=SP[pi][v-1]
  assert actual==src,('every supplied title/blink pixel must reconstruct exactly',variant)
  measured=(ROOT/'assets/title-palette-rgb.bin').read_bytes()
  actual_rgb=bytes(b for row in src for c in row for b in measured[NES[c]*3:NES[c]*3+3])
  (ROOT/f'build/title-expected-{variant}.rgb').write_bytes(actual_rgb)
  Image.frombytes('RGB',(256,240),bytes(v for row in src for c in row for v in RGB[c])).save(ROOT/f'build/title-frame-{variant}.png')
 src=sources[0];actual=sources[0]
 assert actual==src,'every supplied source pixel must reconstruct exactly'
 preview=Image.new('RGB',(256,240));preview.putdata([RGB[c]for r in actual for c in r]);preview.save(ROOT/'build/title-source-preview.png')
 measured=(ROOT/'assets/title-palette-rgb.bin').read_bytes()
 assert len(measured)==192
 actual_rgb=bytes(b for row in src for c in row for b in measured[NES[c]*3:NES[c]*3+3])
 (ROOT/'build/title-expected.rgb').write_bytes(actual_rgb)
 meta={'source':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'background_patterns':background_counts,'chr_patterns_used':list(map(len,patterns)),'sprites':len([i for i in range(0,256,4)if oams[0][i]<240]),'sprite_zero_x':marker_x,'sprite_zero_hit_y':127,'background_switch_y':128,'peak_scanline_sprites':max(row_count.values()),'source_pixels_reconstructed':61440,'nes_color_indexes':NES,'palette_source_rgb':RGB,'blink_reference_sha256':hashlib.sha256((ROOT/'assets/title-blink-reference.gif').read_bytes()).hexdigest(),'blink_frames':5,'blink_tables':animations}
 (ROOT/'build/title-art.json').write_text(json.dumps(meta,indent=2))
 return meta
if __name__=='__main__':print(json.dumps(build(),indent=2))
