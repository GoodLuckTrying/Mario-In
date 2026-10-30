"""Execute assembled 6502 projectile and native damage code, without mocks."""
from pathlib import Path
import hashlib,json
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
meta=json.loads((ROOT/'build/manifest.json').read_text());H=meta['labels']
rom=(ROOT/'dist/Mario in The Legend of Zelda.nes').read_bytes()[16:]
def fresh(bank=0):
 c=MPU();c.memory[0x8000:0xc000]=rom[bank*0x4000:(bank+1)*0x4000];c.memory[0xc000:]=rom[7*0x4000:]
 for n,b in [('01_CODE',1),('06_DATA',6)]:
  start=H['__BANK_'+n+'_LOAD__'];run=H['__BANK_'+n+'_RUN__'];size=H['__BANK_'+n+'_SIZE__'];off=b*0x4000+start-0x8000
  c.memory[run:run+size]=rom[off:off+size]
 c.memory[0x6530:0x67f0]=[0x26]*0x2c0
 for k,v in {'GameMode':5,'M_MODE':5,'IsUpdatingMode':1,'ObjX':120,'ObjY':128,'ObjDir':1}.items():c.memory[H[k]]=v
 return c
def call(c,name):
 c.sp=255;c.stPushWord(0x5ffe);c.pc=H[name]
 for _ in range(50000):
  if c.pc==0x5fff:return
  c.step()
 raise AssertionError((name,hex(c.pc)))
def setv(c,**values):
 for k,v in values.items():c.memory[H[k]]=v
checks=[]
def passed(name,n):
 checks.append({'name':name,'passed':True,'cases':n});print(name,n,'PASS',flush=True)
speed=[48,43,38,33,28,23,18,13,8,8,8,8,12,17,22,27,32,37,42,47]
n=0
for direction in [1,2,4,8]:
 for frac in range(0,256,16):
  c=fresh();setv(c,M_TTL=96,M_X=120,M_Y=128,M_DIR=direction,M_FRAC=frac)
  x,y=120,128
  distances=[]
  for phase in range(20):
   total=frac+speed[phase]*16;step=total//256;frac=total%256
   x+=step*(1 if direction==1 else -1 if direction==2 else 0);y+=step*(1 if direction==4 else -1 if direction==8 else 0)
   call(c,'MarioFireUpdate')
   assert(c.memory[H['M_X']],c.memory[H['M_Y']],c.memory[H['M_FRAC']])==(x,y,frac),(direction,phase,step,c.memory[H['M_X']],c.memory[H['M_Y']])
   assert c.memory[H['M_TTL']]==95-phase
   distances.append(step);n+=1
  assert max(distances)>min(distances),'the projected bounce visibly slows down and speeds up'
passed('four straight directions follow the fixed-point bounce-speed curve without perpendicular drift',n)
n=0
for direction,x,y in [(1,239,128),(2,8,128),(4,120,231),(8,120,64),(1,255,128),(2,0,128),(4,120,255),(8,120,0)]:
 c=fresh();setv(c,M_TTL=96,M_X=x,M_Y=y,M_DIR=direction)
 call(c,'MarioFireUpdate');assert c.memory[H['M_TTL']]==0,(direction,x,y);n+=1
passed('all four screen edges and byte overflows despawn shots without wrapping',n)
for level in [0,1]:
 for tile,solid in [(0x26,False),(0xd8,level==0),(0xf0,True),(0x8d,False)]:
  c=fresh();setv(c,CurLevel=level,M_TTL=96,M_X=120,M_Y=128,M_DIR=1)
  c.memory[0x6530:0x67f0]=[tile]*0x2c0
  call(c,'MarioFireUpdate');assert(c.memory[H['M_TTL']]==0)==solid,(level,tile)
passed('overworld walkable exceptions and dungeon wall thresholds stop fireballs',8)
for state in [0,0x10,0x20,0x40,0x80]:
 c=fresh();setv(c,ObjState=state,ButtonsPressed=128)
 for _ in range(3):call(c,'MarioFireUpdate')
 assert sum(c.memory[H['M_TTL']+i]>0 for i in range(2))==(0 if state&0xc0 else 2)
passed('two-shot cap is independent of native weapon slots and halted states cannot fire',5)
n=0
for mask,timer,direction,hp in [(0,0,1,0x20),(0x20,0,1,0x20),(0,8,1,0x20),(0,0,1,0x10)]:
 c=fresh();i=1
 for k,v in {'ObjX':120,'ObjY':128,'ObjType':1,'ObjHP':hp,'ObjDir':direction,'ObjInvincibilityMask':mask,'ObjInvincibilityTimer':timer}.items():c.memory[H[k]+i]=v
 setv(c,ObjX=16,ObjY=64,M_TTL=96,M_X=124,M_Y=132,M_DIR=1)
 for k,v in [('ObjX',77),('ObjY',99),('ObjDir',0x44)]:c.memory[H[k]+19]=v
 c.x=i;call(c,'CheckMonsterCollisions')
 damaged=not(mask or timer)
 assert c.memory[H['ObjHP']+i]==(max(0,hp-16)if damaged else hp),(mask,timer,c.memory[H['ObjHP']+i])
 assert(c.memory[H['M_TTL']]==0)==(timer==0)
 assert [c.memory[H[k]+19]for k in ['ObjX','ObjY','ObjDir']]==[77,99,0x44]
 assert c.x==i
 if damaged and hp==0x10:assert c.memory[H['ObjMetastate']+i]>=0x10,'native enemy death is entered'
 n+=1
passed('native fire damage, immunity, hit grace, enemy death and room-item restoration remain correct',n)
for occupied in [0,1,40]:
 c=fresh();c.memory[0x200:0x300]=[0]*256
 for i in range(occupied,40):c.memory[0x260+i*4]=0xf8
 setv(c,M_TTL=80,M_X=120,M_Y=128,M_PHASE=3)
 before=c.memory[0x200:0x260];call(c,'MarioFireRender');assert c.memory[0x200:0x260]==before
 if occupied<40:
  a=0x260+occupied*4;assert c.memory[a:a+4]==[128,0x5a,0,120]
passed('fireball OAM uses only free sprites and preserves HUD, sprite zero and Mario',3)
for item,slot,value in [(0,1,4),(1,0,1),(2,0,2),(3,0,3),(4,6,1),(5,5,1),(6,4,1),(7,4,2),(8,2,1),(9,2,2),(10,3,1),(11,13,1),(12,9,1),(13,12,1),(16,8,1),(17,10,1),(18,11,1),(19,11,2),(20,14,1),(21,15,1),(22,16,1),(23,17,1),(28,31,1),(29,29,1),(30,30,1),(31,7,1),(32,7,2)]:
 c=fresh(5);setv(c,MaxBombs=8,CurLevel=1);c.a=item;call(c,'TakeItem')
 assert c.memory[H['Items']+slot]==value,(item,slot,value,c.memory[H['Items']+slot])
passed('native collection retains swords, every B item, raft, ladder, rings, book, shield, keys, bracelet, letter and dungeon map/compass',27)
c=fresh(5)
for slot in [1,2,3,4,5,6,7,8,29]:c.memory[H['Items']+slot]=1
c.y=0
for expected in [1,2,4,5,6,7,8,0]:
 c.a=1;call(c,'FindAndSelectOccupiedItemSlot');assert c.memory[H['SelectedItemSlot']]==expected
passed('the original inventory still equips all eight usable B item slots',8)
for ring in [0,1,2]:
 c=fresh(4);setv(c,InvRing=ring,HeartValues=0x22,HeartPartial=0xff)
 c.memory[0x0d]=0;c.memory[0x0e]=128;c.x=1;call(c,'Link_BeHarmed')
 assert c.memory[H['HeartPartial']]==255-(128>>ring)and c.memory[H['HeartValues']]==0x22
passed('native heart health and both defensive ring upgrades keep their damage reduction',3)
for item,right in [(1,0x0a),(0x0e,0x78)]:
 c=fresh(5);setv(c,ItemTypeToLift=item)
 c.memory[H['ObjX']+19]=120;c.memory[H['ObjY']+19]=112;c.x=0
 call(c,'DrawLinkLiftingItem')
 assert c.memory[H['Sprites']+73]==0x78 and c.memory[H['Sprites']+77]==right,(item,c.memory[H['Sprites']+73],c.memory[H['Sprites']+77])
 assert c.memory[H['Sprites']+78]&0x40==(0 if item==1 else 0x40)
passed('one-handed equipment and two-handed triforce lifts use matching Mario body halves',2)
n=0
for direction,frame,step in [(4,2,(0x5c,0x5e)),(8,3,(0x54,0x60))]:
 for mode in [4,5,16]:
  for moving,state in [(0,0),(direction,0),(direction,0x10)]:
   for flip in [0,1]:
    c=fresh(5);setv(c,ObjDir=direction,ObjInputDir=moving,ObjState=state,GameMode=mode)
    c.memory[0]=120;c.memory[1]=128;c.memory[0xf]=flip
    c.x=0;c.y=0;c.a=frame+(4 if state else 0);call(c,'DrawObjectWithAnim')
    walking=state==0 and(moving or mode in [4,16])
    expected=step if walking else ((0x14,0x16)if direction==4 else(0x18,0x1a))if state else(8,10)if direction==4 else(12,14)
    if flip:expected=expected[::-1]
    assert(c.memory[H['Sprites']+73],c.memory[H['Sprites']+77])==expected,(direction,mode,moving,state,flip)
    n+=1
passed('vertical renderer selects separate strides, standing and attacks including scripted room/stair walks',n)
(ROOT/'build/cpu-verification.json').write_text(json.dumps({'rom_sha256':meta['output_sha256'],'checks':checks},indent=2))
