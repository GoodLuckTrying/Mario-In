"""Compose Mario melee poses from SMB1 cells and pixel-art limbs (24x32)."""
SMALL=[26,27,17,18,19,21]
BIG=[3,5,6,7,8,9]

def unpack(frame):
 p=[[0]*24 for _ in range(32)]
 for tile in range(8):
  d=frame[tile*16:tile*16+16];tx=tile%2*8;ty=tile//2*8
  for y in range(8):
   for x in range(8):p[ty+y][tx+x]=(d[y]>>(7-x)&1)|(d[y+8]>>(7-x)&1)*2
 return p

def pack(p):
 result=bytearray()
 # Eight body cells followed by the four cells of the extended limb.
 for tx,ty in [(x,y) for y in range(0,32,8) for x in [0,8]]+[(16,y) for y in range(0,32,8)]:
  for bit in range(2):
   result.extend(sum(((p[ty+y][tx+x]>>bit)&1)<<(7-x) for x in range(8)) for y in range(8))
 return bytes(result)

def build(frames):
 from PIL import Image,ImageDraw
 result={}
 for big,banks in [(False,SMALL),(True,BIG)]:
  for mode,bank in enumerate(banks):
   crouch=mode//2==1;air=mode//2==2;punch=mode%2==1
   base=(10 if crouch else 4 if air else 24) if big else (16 if air else 23)
   pixels=unpack(frames[base*128:(base+1)*128])
   image=Image.new('L',(24,32));image.putdata([v for row in pixels for v in row]);d=ImageDraw.Draw(image)
   if punch:
    cy=(21 if crouch else 15) if big else 26
    # Start at the shoulder/chest, not the waist. Remove the resting front
    # hand so the extended fist reads as a single arm. SMB's brown/white
    # shirt shade forms the sleeve; skin remains distinct from the torso.
    if big:
     for y in range(19,24):
      for x in range(12,16):
       if pixels[y][x]==2:d.point((x,y),fill=0)
     d.rectangle((10,cy-2,13,cy+1),fill=3)
    d.rectangle((11,cy-1,16,cy+2),fill=3 if big else 1)
    d.rectangle((16,cy,20,cy+2),fill=2)
    d.rectangle((20,cy-1,22,cy+3),fill=2)
    d.line((23,cy,23,cy+2),fill=3)
    d.point((21,cy+1),fill=3)
   else:
    cy=(20 if crouch else 11) if big else 25
    # Keep the planted rear foot and replace the forward leg with a bent
    # raised leg and an extended brown boot at the native kick's height.
    d.rectangle((8,27,15,31),fill=0)
    hip=26 if big else 29
    d.polygon([(8,hip),(8,hip-4),(13,cy+2),(18,cy+2),(18,cy+5),(14,cy+5),(12,hip)],fill=1)
    d.rectangle((17,cy,22,cy+4),fill=3)
    d.line((18,cy-1,21,cy-1),fill=3)
    d.line((23,cy+1,23,cy+4),fill=3)
   result[bank]=pack([list(image.getdata())[y*24:(y+1)*24] for y in range(32)])
 # Guard poses are shown during the native wind-up and recovery frames.
 for big,banks in [(False,[28,25,15]),(True,[29,30])]:
  for mode,bank in enumerate(banks):
   base=(10 if mode==1 else 24) if big else (16 if mode==2 else 23)
   p=unpack(frames[base*128:(base+1)*128])
   cy=(21 if mode==1 else 15) if big else 25
   for y in range(cy-2,cy+3):
    for x in range(11,15):p[y][x]=2 if y<cy else (3 if big else 1)
   result[bank]=pack(p)
 return result
