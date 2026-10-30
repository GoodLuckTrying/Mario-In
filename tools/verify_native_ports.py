"""Execute the installed 6502 routines, not Python approximations of them."""
from pathlib import Path
from py65.devices.mpu6502 import MPU
import hashlib,json
BASE=Path(__file__).resolve().parents[1]
reports={}
class Machine:
 def __init__(self,game):
  self.root=BASE/game;self.meta=json.loads((self.root/'build/manifest.json').read_text());self.c=MPU();self.m=self.c.memory
  self.m[0x8000:]=(self.root/'dist'/('Mario in Kung Fu.nes' if game=='kungfu' else 'Mario and Luigi in Snake Rattle n Roll.nes')).read_bytes()[16:0x8010]
  code=(self.root/'build/hack.bin').read_bytes();self.m[0x6000:0x6000+len(code)]=code
  if game=='snake' and self.meta.get('atlas',{}).get('atlases'):
   rom=(self.root/'dist/Mario and Luigi in Snake Rattle n Roll.nes').read_bytes()
   self.m[0x7200:0x7B00]=rom[16+32768+0x2000:16+32768+0x2900]
   self.m[0x7094]=1;self.m[0x7099]=255
   self.run('DrawStart')
  if game=='snake' and self.meta.get('atlas',{}).get('directional_source'):
   self.m[0x7094]=1;self.m[0x70b4]=1
  if game=='kungfu':self.m[0x7C00:0x8000]=[0]*1024
 def run(self,label,a=None,x=None,y=None):
  c=self.c
  for key,value in [('a',a),('x',x),('y',y)]:
   if value is not None:setattr(c,key,value)
  c.sp=0xFD;self.m[0x1FE:0x200]=[0xFE,0x7F];c.pc=self.meta['labels'][label] if isinstance(label,str) else label
  start=c.processorCycles
  for _ in range(25000):
   if c.pc==0x7FFF:return c.processorCycles-start
   c.step()
  raise AssertionError(f'{label} did not return, PC={c.pc:04X}')
def check(game,name,fn):
 fn();reports.setdefault(game,[]).append({'name':name,'passed':True});print('PASS',game,name)
def kung():
 def damage():
  for power in [1,2]:
   c=Machine('kungfu');m=c.m;m[0x7C00]=power;m[0x4A6]=48;m[0x37A]=2;c.run('DamageGate',x=6)
   assert m[0x7C00]==0 and m[0x4A6]==48 and m[0x7C01]==120
   c.run('DamageGate',x=6);assert m[0x4A6]==48
  c=Machine('kungfu');c.m[0x4A6]=48;c.run('DamageGate',x=6);assert c.m[0x4A6]==255
 check('kungfu','small death, shrink, and damage grace',damage)
 def boxes():
  for power in [0,1,2]:
   for yy in [80,100,135]:
    for offset in [0,4]:
     c=Machine('kungfu');m=c.m;m[0x7C00]=power;m[0xB6]=yy;m[0x94]=120;c.run('HurtBox',x=offset)
     assert m[offset:offset+4]==[114,yy+(34 if power==0 else 18),126,yy+47]
 check('kungfu','actual small/large hurtboxes at multiple heights',boxes)
 def walking():
  c=Machine('kungfu');m=c.m;m[0x51]=2;m[0x4A6]=48;m[0x7C04]=135;m[0xB6]=135;m[0xD4]=127;m[0xE5]=6;m[0x65]=6
  m[0x6A]=1
  for _ in range(80):c.run('Step')
  assert m[0xD4]>127 and m[0x7D01]==0x18
  m[0x6A]=0
  for _ in range(40):c.run('Step')
  old=m[0xD4]
  for _ in range(60):c.run('Step')
  assert m[0xD4]==old
 check('kungfu','SMB acceleration and idle friction',walking)
 def jump():
  heights=[]
  for hold in [1,20]:
   c=Machine('kungfu');m=c.m;m[0x7C04]=135;m[0xB6]=135;m[0x51]=2;m[0x4A6]=48
   ys=[]
   for f in range(90):m[0x6A]=8 if f<hold else 0;c.run('Step');ys.append(m[0xB6])
   assert ys[-1]==135 and m[0x7C08]==0
   heights.append(min(ys))
  assert heights[1]<heights[0]-15
 check('kungfu','variable jump height and exact landing',jump)
 def stomp():
  c=Machine('kungfu');m=c.m;m[0x7C08]=1;m[0x7C05]=2;m[0x7C09]=94;m[0x7C04]=100;m[0x94]=120
  for x in [0,1]:m[0x80+x]=1;m[0x87+x]=0;m[0x9F+x]=1;m[0x8E+x]=120+x*8;m[0xB0+x]=135
  c.run('Stomps');assert m[0x4A0]>=128 and m[0x4A1]>=128 and m[0x7C05]==0xFD and m[0x7C0C]==16
 check('kungfu','adjacent enemy stomps kill and bounce before damage',stomp)
 def power():
  c=Machine('kungfu');m=c.m
  for kills,expected in [(3,0),(4,1),(8,2),(12,2)]:m[0x3B1]=kills;c.run('Fireballs');assert m[0x7C00]==expected
 check('kungfu','kill-earned growth and capped Fire Flower',power)
 def shots():
  c=Machine('kungfu');m=c.m;m[0x7C00]=2;m[0x6A]=0x40;m[0x15]=0x40;m[0x94]=120;m[0x7C04]=100;m[0x69]=1
  c.run('Fireballs');assert m[0x7C24]==47 and m[0x7C20]==124
  c.run('Fireballs');assert m[0x7C25]==47
  c.run('Fireballs');assert sum(v!=0 for v in m[0x7C24:0x7C26])==2
 check('kungfu','two independent fireball slots',shots)
 def firekill():
  c=Machine('kungfu');m=c.m;m[0x7C24]=10;m[0x7C20]=116;m[0x7C22]=150;m[0x7C26]=4;m[0x80]=1;m[0x87]=0;m[0x9F]=1;m[0x8E]=120;m[0xB0]=143
  c.run('Fireballs');assert m[0x4A0]>=128 and m[0x7C24]==0
 check('kungfu','fireball uses native enemy damage and death',firekill)
 def life():
  c=Machine('kungfu');m=c.m;m[0x5C]=3;c.run('LifeGate',a=48,x=7)
  assert c.c.a==48 and c.c.x==7
  m[0x7C00]=2;m[0x5F]=1;c.run('LifeGate',a=48,x=4)
  assert m[0x7C00]==2 and c.c.x==4
  m[0x5C]=2;c.run('LifeGate',a=48);assert m[0x7C00]==0
 check('kungfu','floor transitions retain power; new lives reset small',life)
 def duck():
  c=Machine('kungfu');m=c.m;m[0x7C00]=1;m[0x6A]=4;m[0xB6]=135;m[0x94]=120;c.run('HurtBox',x=0)
  assert m[1]==161 and m[3]==182
  c.run('SelectFrame');assert m[0x7C0F]==10
 check('kungfu','Super Mario ducks with a matching hurtbox',duck)
 def melee():
  for power in [0,1,2]:
   for yy in [80,135]:
    for pose in range(6):
     c=Machine('kungfu');m=c.m;m[0x7C00]=power;m[0xB6]=yy
     c.run('MeleeTop',y=pose);top=c.c.a;c.run('MeleeBottom',y=pose);bottom=c.c.a
     assert yy+16<=top<bottom<=yy+47
     if power==0:assert top>=yy+34
 check('kungfu','punch and kick heights follow Mario in the air and on ground',melee)
 def barrier():
  for kind in range(2,9):
   for side in [0,1]:
    for direction in [1,2]:
     c=Machine('kungfu');m=c.m;m[0x8C]=kind;m[0x4EA+5]=side;m[0x67]=direction
     c.run('BossBlocks');assert bool(c.c.p&1)==(direction==(2 if side else 1))
     m[0x4E3+5]=1;c.run('BossBlocks');assert not c.c.p&1
 check('kungfu','native boss barriers prevent skipping boss fights',barrier)
 def corpse():
  for removed in [0,1]:
   c=Machine('kungfu');m=c.m;m[0x4a6]=255;m[0x86]=removed;m[0x488]=19;m[0x48c]=22;m[0xb6]=205
   for _ in range(20):
    m[0x37a]=8;c.run('DamageGate',x=6)
    assert m[0x4a6]==255 and m[0x86]==removed and m[0xb6]==205 and m[0x48c]==22
 check('kungfu','repeated contacts leave native death HP, actor removal and fall progress intact',corpse)
 def clipping():
  for yy in [205,215,219,230,240,255]:
   c=Machine('kungfu');m=c.m;m[0xb6]=yy;m[0x94]=120;m[0x4a6]=255;m[0x86]=1
   m[0x7c38]=1;m[0x7c0f]=3;c.run('Draw')
   for off in list(range(0x218,0x238,4))+list(range(0x240,0x250,4)):
    assert m[off]>=240 or m[off]>=yy+15
   m[0x86]=0;c.run('Draw');assert all(m[off]==248 for off in range(0x218,0x250,4))
 check('kungfu','off-screen death rows are clipped and removed actors hide all Mario/projectile cells',clipping)
 def melee_poses():
  for power in [0,1,2]:
   for mode,state in enumerate([0x20,0x10,0x22,0x12,0x24,0x14]):
    c=Machine('kungfu');m=c.m;m[0x7c00]=power;m[0x69]=state;m[0x68]=4 if mode>=4 else 1;m[0x4a6]=48
    c.run('SelectFrame');expected=([26,27,17,18,19,21] if power==0 else [3,5,6,7,8,9])[mode]
    assert m[0x7c0f]==expected and m[0x7c38]==1
    m[0x68]=5 if mode>=4 else 3;c.run('SelectFrame');assert m[0x7c38]==0 and m[0x7c0f]!=expected
 check('kungfu','distinct small/large standing, crouching and airborne attacks track native windup and extension',melee_poses)
 def native_art():
  old=Path('C:/nes/Kung Fu (Japan, USA) (En).nes').read_bytes();rom=(BASE/'kungfu/dist/Mario in Kung Fu.nes').read_bytes()
  meta=json.loads((BASE/'kungfu/build/manifest.json').read_text());modified=set(meta['mario_tiles']+meta['extra_tiles']+[meta['fire_tile']])
  for bank in range(35):
   for tile in set(range(512))-modified:
    a=0x8010+bank*8192+tile*16;b=(0x9010 if bank>=31 and tile in meta['stair_hud'] else 0x8010)+tile*16
    assert rom[a:a+16]==old[b:b+16]
 check('kungfu','all scenery and native enemy CHR outside audited Mario cells preserved in every animation bank',native_art)
 def animation_ranges():
  c=Machine('kungfu');m=c.m;m[0x4a6]=48;m[0xb6]=91
  for air in [0,1]:
   for state in [0,1,2,3,4,5,6,7,8,9,12,13,0x10,0x12,0x14,0x20,0x22,0x24,0x30,0x34]:
    for phase in range(256):
     m[0x69]=state;m[0x68]=phase;m[0x7c08]=air;m[0x7c05]=0xfc;m[0x52]=0;m[0x38d]=0
     c.run('SyncNativeAnimation',x=17,y=34)
     assert c.c.x==17 and c.c.y==34 and m[0xb6]==91
     mode=m[0x69]&14;attack=m[0x69]&0x30
     assert mode in [0,2,4,8] and attack!=0x30
     if mode==8:assert m[0x68]==0
     elif mode==4:assert 4<=m[0x68]<=5
     elif attack:assert m[0x68]<=3
     else:assert m[0x68]<2
     c.run(0xA8EB)
     assert m[0x52]<0x4f,(air,state,phase,m[0x69],m[0x68],m[0x52])
 check('kungfu','all 256 animation counter values normalize to legal native states and VRAM pose commands during jumps, attacks and hurt recovery',animation_ranges)
 def sprite_only():
  old=Path('C:/nes/Kung Fu (Japan, USA) (En).nes').read_bytes();rom=(BASE/'kungfu/dist/Mario in Kung Fu.nes').read_bytes()
  for index in range(0x25,0x4f):
   p=rom[16+0x56+index]+256*rom[16+0xa5+index]
   assert p==0x9052 and rom[16+p-0x8000]==0
  assert rom[16+0x1032:16+0x157e]==old[16+0x1032:16+0x157e]
 check('kungfu','obsolete Thomas background poses are empty scripts; original pose data and stage tiles remain intact',sprite_only)
 def stairs_art():
  for stage in range(4):
   for power in [0,1,2]:
    for phase in [0,1]:
     c=Machine('kungfu');m=c.m;m[0x50]=1;m[0x51]=3;m[0x5f]=stage;m[0x60]=3;m[0x4a6]=48;m[0x86]=1;m[0x94]=120;m[0xb6]=100
     m[0x49]=phase*8;m[0x69]=0x24;m[0x7c00]=power;m[0x7c08]=1;m[0x7c01]=120;m[0x7c24]=40
     c.run('SelectFrame');assert m[0x7c0f]==(33 if power==0 else 31)+phase and m[0x7c38]==0 and m[0x7c08]==0 and m[0x7c01]==0 and m[0x7c24]==0 and m[0x7c00]==power
     c.run('Draw');assert m[0x218]==115 and m[0x21b]==112
     m[0x60]=4;c.run('Draw');assert all(m[a]==248 for a in range(0x218,0x250,4))
  c=Machine('kungfu');m=c.m;m[0x60]=2;m[0x63]=8;m[0xb6]=100;c.run('StairSpriteBank')
  assert m[0x63]==0 and m[0x60]==3 and m[0x86]==1 and m[0xb6]==100
 check('kungfu','all stair directions/forms use Mario walking cells, clear frozen attack state, keep the sprite table and hide only after climbing',stairs_art)
 def native_player_art():
  c=Machine('kungfu');m=c.m
  for i in range(7):m[0x3c2+i]=i
  m[0x86]=1;m[0x8d]=9;m[0x94]=120;m[0xb6]=100;m[0xa5]=1;m[0xbd]=1
  c.run(0xB2C8);assert m[0x4b]==0 and m[0x86]==1 and m[0xb6]==100
  m[0x80]=1;m[0x87]=0;m[0x8e]=120;m[0xb0]=100;m[0x9f]=1;m[0xb7]=0
  c.run(0xB2C8);assert m[0x4b]>0
 check('kungfu','native Thomas render is skipped without removing his actor; enemy sprites still render',native_player_art)
 def punch_height():
  c=Machine('kungfu');m=c.m;m[0x7c00]=1;m[0xb6]=100
  rom=(BASE/'kungfu/dist/Mario in Kung Fu.nes').read_bytes()
  for mode,bank in [(1,5),(3,7),(5,9)]:
   ys=[]
   for row,tile in enumerate(c.meta['extra_tiles']):
    at=0x8010+bank*8192+tile*16;data=rom[at:at+16]
    for y in range(8):
     for x in range(8):
      color=(data[y]>>(7-x)&1)|((data[y+8]>>(7-x)&1)*2)
      if color==2:ys.append(row*8+y)
   assert ys and max(ys)-min(ys)>=3
   assert max(ys)<(26 if mode==3 else 20),'Big Mario fist must originate at chest height, above the waist'
   c.run('MeleeTop',y=mode);top=c.c.a;c.run('MeleeBottom',y=mode);bottom=c.c.a
   assert all(top<=100+15+y<=bottom for y in ys),'native punch hitbox must enclose the raised rendered fist'
 check('kungfu','Big Mario standing/crouching/air punch art is raised to the chest with matching native hitboxes',punch_height)
 def effects():
  c=Machine('kungfu');meta=c.meta
  protected={0x0a,0x0b,0xdb,0xdc,0xe4,0xf0}
  assert not protected&set(meta['mario_tiles']+meta['extra_tiles']+[meta['fire_tile']])
  old=Path('C:/nes/Kung Fu (Japan, USA) (En).nes').read_bytes()
  rom=(BASE/'kungfu/dist/Mario in Kung Fu.nes').read_bytes()
  for bank in range(35):
   for tile in protected:
    at=0x8010+bank*8192+tile*16;original=0x8010+tile*16
    assert rom[at:at+16]==old[original:original+16]
 check('kungfu','native knives, hit sparks, smoke, debris and score effects survive every Mario attack/stair bank',effects)
 def enemy_lifecycle():
  for kind in [0,1,2,3,4,5,6,7,10,11,12,13]:
   c=Machine('kungfu');m=c.m;slot=5 if 2<kind<9 else 0
   m[0x80+slot]=1;m[0x87+slot]=kind;m[0x9f+slot]=1;m[0x8e+slot]=120;m[0xb0+slot]=135
   m[0xce+slot]=120;m[0xdf+slot]=1;m[0xd4]=100;m[0xe5]=1;m[0x94]=100;m[0x7e]=1
   m[0x379]=255;m[0x486+slot]=23
   c.run('HitEnemy',x=slot)
   assert m[0x4a0+slot]>=128 and m[0x379]==4 and m[0x486+slot]==0
   for _ in range(90):c.run(0xACDF)
   assert m[0x80+slot]==0,(kind,m[0xb0+slot])
 check('kungfu','every stompable enemy and boss initializes a legal native defeat and frees its actor slot',enemy_lifecycle)
 def contact():
  for kind in [0,1,2,3,4,5,6,7,10,11,12,13]:
   for power in [0,1,2]:
    c=Machine('kungfu');m=c.m;m[0x4a6]=48;m[0xb6]=135;m[0x94]=120;m[0x7c00]=power
    m[0x80]=1;m[0x87]=kind;m[0x9f]=1;m[0x8e]=120;m[0xb0]=169 if kind>=10 else 135
    c.run('Contacts')
    assert ((m[0x4a6]>=128) if power==0 else (m[0x7c00]==0 and m[0x7c01]==120)),(kind,power,m[0x4a6],m[0x7c00])
    c=Machine('kungfu');m=c.m;m[0x4a6]=48;m[0xb6]=60;m[0x94]=120;m[0x7c00]=power
    m[0x80]=1;m[0x87]=kind;m[0x9f]=1;m[0x8e]=120;m[0xb0]=135
    c.run('Contacts');assert m[0x4a6]==48 and m[0x7c00]==power
 check('kungfu','ordinary enemies, low snakes and all bosses damage grounded Mario but cannot hit a clear jump',contact)
 def grips():
  c=Machine('kungfu');m=c.m;m[0x50]=1;m[0x51]=2;m[0x9f]=1
  c.run('GripGate',x=0);assert not c.c.p&1 and m[0x80]==0 and m[0x373]==0
  for x in range(4):m[0x80+x]=7;m[0xb7+x]=8
  m[0x373:0x379]=[2,2,3,3,7,9];c.run('ReleaseGrips')
  assert m[0x80:0x84]==[3]*4 and m[0xb7:0xbb]==[0]*4 and m[0x373:0x379]==[0]*6
 check('kungfu','Mario contact cannot create a grab stack; interrupted stacks release their live actors',grips)
 def landing_stomp():
  c=Machine('kungfu');m=c.m;m[0x7c08]=0;m[0x7c09]=130;m[0x7c04]=135;m[0x94]=120
  m[0x80]=1;m[0x87]=10;m[0x9f]=1;m[0x8e]=120;m[0xb0]=175
  c.run('Stomps');assert m[0x4a0]>=128 and m[0x7c08]==1 and m[0x7c05]==0xfd
 check('kungfu','the floor-landing tick can stomp a short enemy and reactivate the bounce',landing_stomp)

 def story_bank():
  c=Machine('kungfu');rom=(BASE/'kungfu/dist/Mario in Kung Fu.nes').read_bytes();old=Path('C:/nes/Kung Fu (Japan, USA) (En).nes').read_bytes()
  at=0x8010+c.meta['scene_bank']*8192
  assert rom[at:at+8192]==old[0x8010:]
 check('kungfu','native title/story bank preserves every tile including hard-coded story hearts outside actor scripts',story_bank)
 def sylvia():
  c=Machine('kungfu');m=c.m;m[0x80]=1;m[0x87]=8;m[0x9f]=1;m[0x8e]=120;m[0xb0]=135;m[0x94]=120
  m[0x7c08]=1;m[0x7c05]=2;m[0x7c09]=84;m[0x7c04]=90;c.run('Stomps');assert m[0x4a0]==0
  m[0x7c24]=10;m[0x7c20]=116;m[0x7c22]=150;m[0x7c26]=4;c.run('Fireballs');assert m[0x4a0]==0
 check('kungfu','Sylvia is protected from Mario stomps and fireballs',sylvia)

def snake():
 def growth():
  for player in [0,1]:
   c=Machine('snake');m=c.m;m[0x59F+player]=1;m[0x3DF+player]=2;c.run('PowerStep',x=player)
   for weight in [4,7,10,13,16]:
    m[0x59F+player]=weight;c.run('PowerStep',x=player);assert m[0x7000+player]==0
   for n in range(1,7):
    m[0x56]=player;c.run('EatGate',x=player,a=player);assert m[0x7000+player]==min(2,n//2)
   m[0x3DF+player]=3;c.run('PowerStep',x=player);assert m[0x7000+player]==2
   m[0x3DF+player]=1;c.run('PowerStep',x=player);assert m[0x7000+player]==0
 check('snake','two eaten Pibbles per upgrade; weight and 1-Ups never change the form',growth)
 def life_paths():
  for player in [0,1]:
   c=Machine('snake');m=c.m;m[0x7000+player]=2;m[0x7004+player]=1;m[0x3DF+player]=3
   c.run(0xBE06,x=player)
   assert m[0x7000+player]==2 and m[0x7004+player]==1
   c.run('RespawnGate',x=player)
   assert m[0x7000+player]==0 and m[0x7004+player]==0 and m[0x7008+player]==0
 check('snake','shared room continuation preserves form; real death resets it',life_paths)
 def draw():
  for player in [0,1]:
   for form in [0,1,2]:
    c=Machine('snake');m=c.m;m[0x3B7+player]=120;m[0x3CB+player]=100;m[0x5C7+player]=255
    m[0x70a4+player]=form;m[0x49B+player]=player+1
    c.run('DrawMario',y=player,x=0x20)
    assert c.c.x==0x60
    visible=[i for i in range(16)if m[0x220+i*4]<240]
    assert len(visible)==(8 if form==0 else 16)
    assert m[0x222]&3==(0 if player==0 or form==2 else 3)
    assert m[0x242]&3==2
    assert min(m[0x220+i*4]for i in visible)==(91 if form==0 else 75)
 check('snake','both forms reserve atomic OAM cells, with correct visible heights and independent clothing/skin palettes',draw)
 def jump():
  for player in [0,1]:
   c=Machine('snake');c.m[0x56]=player;c.run('JumpGate',x=player,a=2);assert c.m[0x5C7+player]==4
 check('snake','Mario jump replaces native player jump strength',jump)
 def damage():
  for player in [0,1]:
   c=Machine('snake');m=c.m;m[0xB]=player;m[0x7000+player]=2;m[0x59F+player]=13|player*64
   c.run('DamageGate');assert m[0x7000+player]==0 and m[0x40D+player]==120 and m[0x59F+player]==13|player*64
 check('snake','damage shrinks either player without losing puzzle weight',damage)
 def project():
  c=Machine('snake');m=c.m
  for slot in range(4):
   for xx,yy,zz in [(60,40,20),(300,260,280),(10,20,0)]:
    for a,v in [(0x7040,xx),(0x7048,yy),(0x7050,zz)]:m[a+slot]=v&255;m[a+4+slot]=v>>8
    camera=(xx+yy-120)&65535;m[0x6D]=camera>>8;m[0x6E]=camera&255;m[0x6F]=0x3F;m[0x70]=0x80
    c.run('ProjectShot',x=slot)
    assert m[0x7064+slot]==120
    assert m[0x7068+slot]==((xx-yy)//2-zz-0x3F80)&255
 check('snake','fireballs use the native isometric world projection',project)
 def shots():
  c=Machine('snake');m=c.m
  for player in [0,1]:
   m[0x4D7+player]=100;m[0x4FF+player]=80;m[0x527+player]=32;m[0x7020+player]=1
   c.run('SpawnShot',x=player);c.run('SpawnShot',x=player);c.run('SpawnShot',x=player)
  assert m[0x7058:0x705C]==[48]*4 and m[0x705C:0x7060]==[3]*4 and m[0x7060:0x7064]==[0]*4
 check('snake','two fireballs per player with separate world positions',shots)
 def shot_facing():
  # Independent screen-space directions measured from native world motion.
  directions={1:(1,1),2:(-1,-1),4:(-1,1),5:(0,1),6:(-1,0),8:(1,-1),9:(1,0),10:(0,-1)}
  sign=lambda v:(v>0)-(v<0)
  for player in [0,1]:
   for direction,expected in directions.items():
    c=Machine('snake');m=c.m;m[0x7020+player]=direction;c.run('SpawnShot',x=player)
    n=player*2;dx=m[0x705c+n];dy=m[0x7060+n];dx=dx-256 if dx>=128 else dx;dy=dy-256 if dy>=128 else dy
    assert (sign(dx+dy),sign(dx-dy))==expected
 check('snake','both players fire in the eight independently measured native screen-space movement directions',shot_facing)
 def preserved():
  orig=Path('C:/nes/Snake Rattle n Roll (USA).nes').read_bytes();rom=(BASE/'snake/dist/Mario and Luigi in Snake Rattle n Roll.nes').read_bytes()
  assert rom[0x10010:0x18010]==orig[0x8010:]
 check('snake','all original scenery and CHR audio/code banks preserved',preserved)
 def gravity():
  for stage,held,velocity,expected in [(0,128,4,0xE0),(0,0,4,0x90),(0,128,255,0x90),(10,0,4,0xF0)]:
   c=Machine('snake');m=c.m;m[0xDF5A]=0x60;m[0xAA]=stage;m[0x16]=held;m[0x5C7]=velocity;m[0x49B]=1
   c.run('GravityGate',x=0,a=0xF0);assert m[4]==expected
 check('snake','variable gravity preserves the Moon level physics',gravity)
 def tongue():
  for player in [0,1]:
   for color in range(3):
    c=Machine('snake');m=c.m;m[2]=player;m[0x49B+player]=player+1;m[0x49D]=6;m[0x5B5]=color;m[0x56]=2
    m[0x3B9]=m[0x48F+player]=100;m[0x3CD]=m[0x491+player]=100;m[0x529]=m[0x527+player]=32
    c.run(0xB315,x=2)
    assert m[0x49D]==6 and m[0x493+player]==0,'food needs an active tongue'
    m[0x41F+player]=1;c.run(0xB315,x=2)
    assert m[0x49D]!=6 and m[0x493+player]==0x80+color
    assert sum(m[0x3F9:0x3FF])==1
 check('snake','both players need an active tongue to capture food with native color and score',tongue)
 def tongue_art():
  original=Path('C:/nes/Snake Rattle n Roll (USA).nes').read_bytes();rom=(BASE/'snake/dist/Mario and Luigi in Snake Rattle n Roll.nes').read_bytes()
  assert rom[16+0x3315:16+0x33D7]==original[16+0x3315:16+0x33D7]
  meta=json.loads((BASE/'snake/build/manifest.json').read_text())
  art=meta['atlas'];slots=art['private_slots']
  assert len(slots)==33 and not set(slots)&set(art['used_native_tiles'])
  assert rom[0x10010:0x18010]==original[0x8010:]
  assert rom[16+0x7DAC]==0
 check('snake','native cover, door, Pibble, HUD, tongue and NPC source banks and tile numbers preserved',tongue_art)
 def directional_art():
  import sys
  sys.path.insert(0,str(BASE/'snake/tools'));from directional import tile
  sys.path.insert(0,str(BASE/'tools'));from directional_art import pose
  from atlas import recolor
  packets=(BASE/'snake/build/directional-packets.chr').read_bytes()
  rom=(BASE/'snake/dist/Mario and Luigi in Snake Rattle n Roll.nes').read_bytes()
  assert rom[0x18010:0x18010+len(packets)]==packets
  n=0
  for power in range(3):
   for view in ['front','front_right','right','back_right','back']:
    for state,step in [('idle',0),('walk',0),('walk',1),('walk',2),('jump',0)]:
     p=pose('small'if power==0 else'big',view,state,step)
     if power==0:p=[[0]*16 for _ in range(16)]+p
     raw=b''.join(tile(p,x,y)for y in range(0,32,8)for x in [0,8])
     cloth=b''.join(recolor(raw[i:i+16],[0,3,0,2]if power==2 else[0,2,0,1])for i in range(0,128,16))
     skin=b''.join(recolor(raw[i:i+16],[0,0,2,0])for i in range(0,128,16))
     assert packets[n*256:(n+1)*256]==cloth+skin
     n+=1
  assert n==75
 check('snake','all 75 source-exact directional frames and approved Fire pixel roles are present in the ROM',directional_art)
 def directions():
  views={0:10,1:5,2:15,4:5,5:0,6:10,8:15,9:10,10:20}
  for p in [0,1]:
   for power in [0,1,2]:
    for direction,base in views.items():
     for anim in range(5):
      c=Machine('snake');m=c.m;m[0x7000+p]=power;m[0x7020+p]=direction
      m[0x5c7+p]=1 if anim==4 else 255;m[0x16+p]=(direction or 1) if anim in [1,2,3] else 0;m[3]=max(0,anim-1)*8
      c.run('SelectDirection',x=p)
      assert m[0x70ae+p]==power*25+base+anim
      assert m[0x70b0+p]==power and m[0x70b2+p]==(64 if direction in[0,1,8,9]else 0)
 check('snake','all eight isometric directions, small/big/Fire forms and idle/walk/jump frames select independently for both players',directions)
 def manholes():
  for player in [0,1]:
   for index in range(24):
    c=Machine('snake');m=c.m;m[0xCCF2]=0x60;m[0x4D7+player]=0x79;m[0x4C3+player]=3;m[0x4FF+player]=0x15
    m[0x1B0+index*2]=0x73;m[0x1B1+index*2]=0x1A
    c.run('ManholeLookup',x=player);assert c.c.y==index*2
   c=Machine('snake');m=c.m;m[0x4D7+player]=0x79;m[0x4C3+player]=3;m[0x4FF+player]=0x15;m[0x56]=player
   c.c.sp=0xFB;m[0x1FC:0x200]=[0x78,0xC4,0xFE,0x7F];c.c.pc=c.meta['labels']['ManholeLookup']
   for n in range(2000):
    if c.c.pc==0x7FFF:break
    c.c.step()
   assert c.c.pc==0x7FFF and c.c.sp==0xFF and c.c.x==player
 check('snake','all 24 manhole entries work and missing entries return without locking',manholes)
 def remap():
  for player in [0,1]:
   c=Machine('snake');m=c.m;m[0x16+player]=0xC1;m[0x18+player]=0x40;m[0x49B+player]=player+1;m[0x59F+player]=4+player*64;m[0x56]=player
   c.run('ReadFireButtons')
   assert m[0x16+player]==0xC1 and m[0x18+player]==0x40 and m[0x7088+player]==0x40
   m[0x16+player]=0xC1;c.run('ReadFireButtons');assert m[0x7088+player]==0
   m[0x16+player]=1;c.run('ReadFireButtons');m[0x16+player]=0x41;c.run('ReadFireButtons');assert m[0x7088+player]==0x40
   m[0x96FB]=0x60;m[0x41F+player]=0x82;m[0x493+player]=0x81;c.run('PlayerGate',x=player)
   assert m[0x41F+player]==0x82 and m[0x493+player]==0x81
 check('snake','B reaches both attacks, preserves native eating state, and fires once per press',remap)
 def boss():
  for player in [0,1]:
   c=Machine('snake');m=c.m;m[0xAA]=10;m[0x49B+player]=player+1;m[0x49D]=0x1A;m[0x7022]=player*2
   hits=0
   while m[0x49D]==0x1A and hits<25:
    c.run('FireHit',y=2);hits+=1
   assert 7<hits<=20 and m[0x49D]==0x18,(hits,m[0x49D])
 check('snake','fireballs damage and defeat the Moon boss through native HP logic',boss)
kung();snake()
for game,checks in reports.items():
 meta=json.loads((BASE/game/'build/manifest.json').read_text());(BASE/game/'build/cpu-verification.json').write_text(json.dumps({'rom_sha256':meta['output_sha256'],'checks':checks},indent=2))
