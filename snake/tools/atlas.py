"""Pack original NPC tiles and Mario into separate MMC1 sprite atlases."""
from py65.devices.mpu6502 import MPU

POSES=[(0,23,True),(4,12,True),(8,13,True),(12,16,True),(16,24,False),(24,0,False),(32,4,False)]

def flip(data,flags):
 return bytes(int(f'{b:08b}'[::-1],2) if flags&64 else b for plane in [data[:8],data[8:]] for b in (plane[::-1] if flags&128 else plane))

def recolor(data,colors):
 p=[((data[y]>>(7-x))&1)|(((data[y+8]>>(7-x))&1)<<1) for y in range(8) for x in range(8)]
 return bytes(sum((colors[p[y*8+x]]&1)<<(7-x) for x in range(8)) for y in range(8))+bytes(sum((colors[p[y*8+x]]>>1)<<(7-x) for x in range(8)) for y in range(8))

def native_tiles(old):
 # Covers use $15-$17; doors/scales/elevators use $27-$30. The normal
 # NPC renderer starts at $31, but that is not the start of NPC graphics.
 # Include earlier shared poses, every directional tongue tile and direct
 # single-sprite effects; the Moon boss also reuses head tiles $22-$25.
 used={0,1,0xBD,0xBE}|set(range(0x9A,0xA2))|set(range(0x34,0x3E))
 poses={}
 for pose in range(0x12,0x9B):
  c=MPU();m=c.memory;m[0x8000:]=old[16:0x8010]
  m[0x75]=128;m[0x5C]=128;m[0x4AF+2]=pose;m[0x49B+2]=6
  c.x=0;c.y=2;c.sp=0xFD;m[0x1FE:0x200]=[0xFE,0x7F];c.pc=0xFE60
  for _ in range(10000):
   if c.pc==0x7FFF:break
   c.step()
  else:raise AssertionError(('native metasprite did not return',pose))
  tiles=sorted(set(m[0x201:0x200+c.x:4]));poses[pose]=tiles;used.update(tiles)
 # HUD sprite templates plus the timer/life digits above.
 used.update(old[16+0x7C20:16+0x7C3F:4])
 return sorted(used),poses

def build(old,smb,frames):
 used,poses=native_tiles(old);banks={};pools=[];audit=[]
 mario={}
 for start,pose,small in POSES:
  data=frames[pose*128+(64 if small else 0):pose*128+128]
  for n in range(0,len(data),16):mario[start+n//16]=data[n:n+16]
 # Reuse the standing head/torso while the walking legs animate. These
 # retained SMB1 cells avoid overwriting graphics shared with native actors.
 for logical in range(24,30):mario[logical]=mario[logical-8]
 for logical in [8,9,12,13]:mario[logical]=mario[logical%4]
 for logical in range(32,38):mario[logical]=mario[logical-16]
 common=set(used)|{0x4E,0x4F,0x50,0xEF}
 for group,source in enumerate([1,4,5]):
  used=sorted(common|(set(range(0x22,0x26)) if source==5 else set()))
  patterns=[old[0x8010+source*4096+t*16:0x8010+source*4096+(t+1)*16] for t in range(256)]
  free=[t for t in range(256) if t not in used];indices={}
  def add(data):
   options=[(flip(data,f),f) for f in [0,64,128,192]]
   packed,flags=min(options)
   if packed not in indices:
    assert free,('atlas full',source,variant)
    index=free.pop(0);indices[packed]=(index,0);patterns[index]=packed
   index,stored_flip=indices[packed]
   return index,flags^stored_flip
  for tile in used:
   at=0x8010+source*4096+tile*16
   data=old[at:at+16]
   packed,flags=min((flip(data,f),f) for f in [0,64,128,192])
   indices.setdefault(packed,(tile,flags))
  blank=add(bytes(16));native_ids=list(range(256));native_flags=[0]*256
  base=list(patterns);base_indices=dict(indices);base_free=list(free)
  pool=bytearray(native_ids+native_flags)
  for variant in range(8):
   patterns[:]=base;indices.clear();indices.update(base_indices);free[:]=base_free
   body=[blank[0]]*40;bodyflip=[0]*40;skin=[blank[0]]*40;skinflip=[0]*40
   firebody=[blank[0]]*8;firebodyflip=[0]*8;fireskin=[blank[0]]*8;fireskinflip=[0]*8
   phase=(variant-2)&1
   firepose=16+((variant-2)//2)*8 if variant>=2 else None
   for logical,data in mario.items():
    start=next(start for start,_,small in reversed(POSES) if logical>=start)
    # Fire characters are always large. Normal small walking alternates the
    # standing pose with walk 2, leaving native directional tongue tiles intact.
    if (variant==1 and start<16) or (variant!=1 and start==4):continue
    if variant>=2 and ((phase==0 and start in [4,8]) or (phase==1 and start in [4,24])):continue
    colors=[0,3,0,2] if variant==1 else [0,2,0,1]
    body[logical],bodyflip[logical]=add(recolor(data,colors))
    skin[logical],skinflip[logical]=add(recolor(data,[0,0,2,0]))
   if variant>=2:
    for n in range(8):
     firebody[n],firebodyflip[n]=add(recolor(mario[firepose+n],[0,3,0,2]))
     fireskin[n],fireskinflip[n]=add(recolor(mario[firepose+n],[0,0,2,0]))
   fire=[];fireflip=[]
   for tile in [0x64,0x64]:
    at=0x8010+tile*16;t,f=add(smb[at:at+16]);fireflip.append(f^(192 if fire else 0));fire.append(t)
   bank=8+group*8+variant
   banks[bank]=b''.join(patterns).ljust(4096,b'\0')
   pool.extend(body+bodyflip+skin+skinflip+firebody+firebodyflip+fireskin+fireskinflip+fire+fireflip)
   audit.append({'source':source,'variant':variant,'bank':bank,'patterns':256-len(free),'used_native_tiles':used,'mario_tiles':[t for t in range(256) if t not in used and t not in free]})
  assert len(pool)==2080
  pools.append(bytes(pool).ljust(4096,b'\0'))
 return banks,pools,{'used_native_tiles':sorted(common),'native_pose_tiles':poses,'atlases':audit,'pool_bytes':2080,'variant_bytes':196}
