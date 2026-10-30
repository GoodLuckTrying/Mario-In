from pathlib import Path
import json,random
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
def run():
 meta=json.loads((ROOT/'build/manifest.json').read_text());H=meta['labels'];rom=(ROOT/'dist/Mario and Luigi in WWF WrestleMania.nes').read_bytes();checks=[]
 def machine():
  p=MPU();p.memory[0x8000:]=rom[16+4*32768:16+5*32768];m=p.memory
  m[0x12d]=2;m[0x12e]=0;m[0x2a]=0;m[0x2b]=1;m[0x78]=63
  m[0x2c]=80;m[0x2d]=150;m[0x2e]=m[0x2f]=180;m[0x42]=m[0x43]=12;m[0x3a]=0;m[0x3b]=1
  m[0x79]=m[0x7a]=200
  return p,m
 def call(p,name,x=None):
  if x is not None:p.x=x
  p.sp=0xff;p.stPushWord(0x5ffe);p.pc=H[name];steps=0
  while p.pc!=0x5fff:
   p.step();steps+=1
   assert steps<50000,(name,hex(p.pc))
  return steps
 cases=0
 for owner in range(2):
  p,m=machine();call(p,'Spawn',owner);assert m[0x4b0+owner*2]==60
  call(p,'Spawn',owner);assert m[0x4b1+owner*2]==0
  m[0x4cc+owner]=0;call(p,'Spawn',owner);assert m[0x4b1+owner*2]==60
  m[0x4cc+owner]=0;call(p,'Spawn',owner);assert sum(v>0 for v in m[0x4b0:0x4b4])==2
  for _ in range(80):m[0x8d]=(m[0x8d]+1)&255;call(p,'Update')
  assert not any(m[0x4b0:0x4b4]);cases+=4
 checks.append({'name':'two independent fireball slots per human, cooldown, lifetime and cleanup','cases':cases,'passed':True})
 cases=0
 for owner in range(2):
  for direction in range(2):
   for x in range(256):
    p,m=machine();m[0x4b0]=10;m[0x4b4]=x;m[0x4b8]=200;m[0x4bc]=8;m[0x4c4]=direction;m[0x4c8]=owner
    call(p,'Update');alive=8<=x+(-4 if direction==0 else 4)<240
    assert (m[0x4b0]>0)==alive
    if alive:assert m[0x4b4]==x+(-4 if direction==0 else 4)
    cases+=1
 checks.append({'name':'fireball horizontal bounds never wrap for either owner/direction','cases':cases,'passed':True})
 cases=0
 for owner in range(2):
  target=owner^1;shot=owner*2
  for identity in range(6):
   for hp in [0,1,14,27,28,29,64,200]:
    p,m=machine();m[0x2a+owner]=identity;m[0x79+owner]=hp;m[0x79+target]=173
    m[0x32+target]=7;m[0x34+target]=3
    m[0x4b0+shot]=40;m[0x4b4+shot]=m[0x2c+target]+4;m[0x4b8+shot]=168;m[0x4bc+shot]=16;m[0x4c8+shot]=owner
    call(p,'FireHit',shot);assert m[0x79+owner]==max(0,hp-14);assert m[0x79+target]==173,'the shooter must never lose energy from its own fireball'
    assert m[0xa2+target]==(255 if hp<=14 else 0),'fatal fireballs latch the native down/pin state immediately'
    assert m[0x32+target]==7 and m[0x34+target]==3,'native CHR streamer keeps its current pose until the hurt script changes it'
    assert m[0x4b0+shot]==0 and m[0x4ce+target]==18
    assert 0<m[0x3c+target]<32 and m[0x40+target]==0 and m[0x3c+owner]==0
    before=m[0x79+owner];m[0x4b0+shot]=40;call(p,'FireHit',shot);assert m[0x79+owner]==before and m[0x79+target]==173
    cases+=2
 checks.append({'name':'both fireball owners damage only the defender energy/actor, for all six original identities, with hit grace','cases':cases,'passed':True})
 cases=0
 for actor in range(2):
  p,m=machine();other=actor^1;other_xy=(m[0x2c+other],m[0x2e+other])
  for y in range(256):
   for x in [0,8,20,50,80,120,184,214,240,255]:
    m[0x2c+actor]=x;m[0x2e+actor]=y;call(p,'ConstrainRing',actor)
    rx,ry=m[0x2c+actor],m[0x2e+actor];depth=ry-168
    assert 169<=ry<=199 and 51-depth<=rx<184+depth,'free bodies must be inside the native perspective ring'
    if 169<=y<=199 and 51-(y-168)<=x<184+(y-168):assert(rx,ry)==(x,y),'legal native movement is unchanged'
    assert(m[0x2c+other],m[0x2e+other])==other_xy,'never move the other wrestler'
    call(p,'ConstrainRing',actor);assert(m[0x2c+actor],m[0x2e+actor])==(rx,ry),'correction must settle in one update'
    cases+=1
 for actor in range(2):
  for guard in [None,0x12d,0x4f6,0xcb,0xc0]:
   p,m=machine();m[0x2e+actor]=208
   if guard is not None:m[guard+actor]=255 if guard==0x12d else 1
   call(p,'ConstrainHumanPositions');assert m[0x2e+actor]==(199 if guard is None else 208),'CPU bodies, native rope scripts and active pins retain coordinate ownership'
   cases+=1
  p,m=machine();m[0x2f]=208;m[0xa6]=1;call(p,'Update');assert m[0x2f]==208,'pause freezes recovery too'
  m[0xa6]=0;call(p,'Update');assert m[0x2f]==199;cases+=2
 checks.append({'name':'native ring polygon, both actors/all depth bytes, legal-coordinate preservation, settled correction, pause and native special-state ownership','cases':cases,'passed':True})
 cases=0
 for owner in range(2):
  for identity in range(6):
   p,m=machine();target=owner^1;shot=owner*2;m[0x2a+owner]=identity;m[0xc0+target]=1
   m[0x3c+target]=12;m[0x40+target]=23
   m[0x4b0+shot]=40;m[0x4b4+shot]=m[0x2c+target]+4;m[0x4b8+shot]=168;m[0x4bc+shot]=16;m[0x4c8+shot]=owner
   call(p,'FireHit',shot)
   assert m[0x79]==200 and m[0x7a]==200 and m[0x3c+target]==12 and m[0x40+target]==23 and m[0xc0+target]==1,'fireballs must not interrupt a native rope/climbing script into an invalid hurt state'
   cases+=1
 checks.append({'name':'both projectile owners preserve native rope/climbing immunity and script state for all original identities','cases':cases,'passed':True})
 cases=0
 for mode in [0,1,2,3,4,5,6,7]:
  for a in [0,1]:
   p,m=machine();n=[1,1,2,2,3,4,5,6][mode];m[0x100]=n;m[0x12b]=255 if mode==0 else 1
   for i in range(n):m[0x125+i]=(a+i)&1
   if mode==0:m[0x126]=5
   before=m[0x125:0x125+n];call(p,'Roster');assert m[0x125:0x125+n]==before and all(i<6 for i in m[0x125:0x12b]);cases+=1
 checks.append({'name':'all eight native modes keep chosen human brothers and valid original CPU identities','cases':cases,'passed':True})
 # Render native 8x8 OAM cells back into their unmirrored 24x32 poses.
 # Compare canonical packed art with the pre-deduplication preview pixels.
 from PIL import Image
 preview=Image.open(ROOT/'build/poses.png').convert('RGB');palette=[(0,0,0),(255,254,255),(234,158,34),(181,49,32)]
 streamed=(ROOT/'build/streamed-poses.chr').read_bytes()
 for pose in range(21):
  for cell in range(12):
   tile=streamed[pose*224+cell*16:][:16]
   p=[[((tile[y]>>(7-x))&1)|(((tile[y+8]>>(7-x))&1)<<1)for x in range(8)]for y in range(8)]
   for y in range(8):
    for x in range(8):assert palette[p[y][x]]==preview.getpixel((pose*96+(cell%3*8+x)*4,(cell//3*8+y)*4))
 checks.append({'name':'all 21 streamed body, melee and directional poses exactly reconstruct','cases':21*12*64,'passed':True})
 cases=0
 for phase in range(6):
  actor=phase&1
  for pose in range(21):
   p,m=machine();m[0x27]=255;m[0x28]=0xab;m[0x71]=phase;m[0x4d8+actor]=pose
   m[0x200:0x340]=[0x55]*320
   call(p,'StageDirectional')
   assert bytes(m[0x200:0x2e0])==streamed[pose*224:(pose+1)*224]
   assert m[0x2e0:0x340]==[0x55]*96,'the remainder of the original 20-tile packet is untouched'
   assert m[0x6100+actor]==pose and m[0x6102+actor]==[0xeb,0xc3,0xd7,0xeb,0xc3,0xd7][phase]and m[0x6104+actor]==1
   p,m=machine();m[0x27]=255;m[0x28]=0xab;m[0x71]=phase;m[0x12d+actor]=255;m[0x4d8+actor]=pose;m[0x200:0x340]=[0x55]*320
   call(p,'StageDirectional');assert m[0x200:0x340]==[0x55]*320,'original CPU wrestler CHR packets must remain untouched'
   cases+=2
 checks.append({'name':'native six-phase CHR packets, both owners, all poses/fireballs and original CPU packet preservation','cases':cases,'passed':True})
 for actor,fresh in [(0,0x10),(1,0x0e)]:
  for button,pose in [(0x40,4),(0x80,5)]:
   p,m=machine();m[fresh]=button;call(p,'Update');assert m[0x4d0+actor]==pose and m[0x4d2+actor]>0
   call(p,'SelectPose',actor);assert m[0x4d8+actor]==pose
 checks.append({'name':'both controllers select the distinct punch and kick recovery poses','cases':4,'passed':True})
 return checks
if __name__=='__main__':print(json.dumps(run(),indent=2))
