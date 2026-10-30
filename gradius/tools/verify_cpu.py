"""Execute the delivered 6502 code with native terrain and damage routines."""
from pathlib import Path
import json,random
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
H=json.loads((ROOT/'build/manifest.json').read_text())['labels']
ROM=(ROOT/'dist/Mario in Gradius.nes').read_bytes()
def machine():
 c=MPU();c.memory[0x8000:]=ROM[16:0x8010];c.memory[0x6000:0x7000]=(ROOT/'build/hack.bin').read_bytes();return c
def call(c,pc):
 c.sp=0xfd;c.memory[0x1fe:0x200]=[0xfe,0x7f];c.pc=pc
 for _ in range(10000):
  if c.pc==0x7fff:return
  if c.pc==0xec1e:c.pc=0x6ff0;c.memory[c.pc]=0x60
  c.step()
 raise AssertionError(hex(c.pc))
checks=[]
def check(name,fn):fn();checks.append(name)
for player in [0,1]:
 for speed in [0,1,4,8,14]:
  def float_motion(player=player,speed=speed):
   c=machine();m=c.memory;c.x=player;m[0x40]=speed;m[0x320]=96
   y8=96*8;vy=0;cap=16+min(speed,8)*4
   buttons=[0]*20+[8]*30+[9]*10+[0]*20+[4]*10+[8]*90+[0]*100
   for held in buttons:
    m[7+player]=held
    vy=max(-cap,vy-2) if held&8 else min(24 if held&4 else 16,vy+(2 if held&4 else 1))
    y8+=vy
    if y8<16*8:y8=16*8;vy=0
    if y8>=188*8:y8=188*8;vy=0
    call(c,H['FloatStep'])
    assert (m[0x320],m[0x340],m[0x7040])==(y8//8,(y8%8)*32,vy&255),(player,speed,held,y8,vy)
   call(c,H['ResetFloat']);assert m[0x7040]==0 and m[0x7041]==0
   m[0x320]=96;m[0x340]=192;m[7+player]=0;call(c,H['FloatStep'])
   assert m[0x320]==96 and m[0x340]==32,'New life must discard stale velocity/fraction'
  check(f'gravity-lift-controller-{player}-speed-{speed}',float_motion)
def floatier():
 c=machine();m=c.memory;m[0x320]=60
 for t in range(24):call(c,H['FloatStep'])
 assert m[0x320]-60<=33 and m[0x7040]<=16,'Gravity and terminal fall must be gentler than the preceding 54-pixel fall'
check('gentler-gravity-and-terminal-fall',floatier)
for options in [0,1,2]:
 def double_limits(options=options):
  c=machine();m=c.memory;m[0x44]=2;m[0x45]=options;m[0x35]=20;m[0x05]=128;m[0x07]=128
  for i in range(3):m[0x360+i]=80+i*16;m[0x320+i]=80
  for shot in range(3):
   call(c,H['DoubleFire'])
   for origin in range(options+1):
    assert m[0x123+origin]==6 and m[0x126+origin]==0x24
    if shot:assert m[0x7050+origin]==6 and m[0x7053+origin]==0x24
  # Filling one direction must not prevent replacing a shot in the other.
  m[0x7053]=0;call(c,H['DoubleFire']);assert m[0x7053]==0x24 and m[0x7050]==6
  m[0x7050]=0;call(c,H['DoubleFire']);assert m[0x7050]==6 and m[0x7053]==0x24
  assert sum(m[0x123:0x129].count(t) for t in [6,0x24])+sum(m[0x7050:0x7056].count(t) for t in [6,0x24])==4*(options+1)
  saved=[m[a:a+6] for a in [0x123,0x163,0x363,0x323,0x7020,0x7030]]
  call(c,H['SwapShots']);call(c,H['SwapShots'])
  assert saved==[m[a:a+6] for a in [0x123,0x163,0x363,0x323,0x7020,0x7030]]
 check(f'independent-double-pools-{options}-options',double_limits)
def extra_native_kill():
 c=machine();m=c.memory;m[0x100]=1;m[0x7005]=1;m[0x7050]=6;m[0x7070]=80;m[0x7080]=80;m[0x7090]=8
 m[0x30c]=0x85;m[0x10c]=1;m[0x12c]=0x11;m[0x36c]=84;m[0x32c]=82
 call(c,H['FireLoop']);call(c,H['CombatGate'])
 assert m[0x30c]!=0x85 and m[0x7050]==0,'Virtual fireball must use real enemy damage and free its own slot'
 assert m[0x123]==0,'Virtual collision must restore the original native pool'
check('extra-fireball-native-kill',extra_native_kill)
def extra_boss():
 c=machine();m=c.memory;m[0x100]=1;m[0x7005]=1;m[0x1b]=0x85
 m[0x315]=0x98;m[0x115]=0x90;m[0x135]=0x6c;m[0x469]=3;m[0x495]=1
 for slot in range(6):
  m[0x7050+slot]=6 if slot<3 else 0x24;m[0x7060+slot]=0 if slot<3 else 2
  m[0x7070+slot]=80;m[0x7080+slot]=80;m[0x7090+slot]=8 if slot<3 else 240
  call(c,H['FireLoop']);m[0x375]=m[0x7070+slot]+8;m[0x335]=m[0x7080+slot]+7
  call(c,H['CombatGate']);assert m[0x475]==slot+1 and m[0x7050+slot]==0
 m[0xa8]=9;call(c,0xb914);assert m[0x1b]==0x86 and m[0x315]==2
check('all-extra-lanes-native-big-core-defeat',extra_boss)
for extra in [False,True]:
 def arm_damage(extra=extra):
  c=machine();m=c.memory;m[0x100]=1;m[0x7005]=1;m[0x19]=4
  m[0x61a]=84;m[0x622]=82
  for i in range(6):
   m[0x600]=1;m[0x605]=0
   kind,xpos,ypos=(0x7050,0x7070,0x7080) if extra else (0x123,0x363,0x323)
   m[kind+i]=6;m[xpos+i]=80;m[ypos+i]=80
   call(c,H['CombatGate'])
   assert m[0x605]==1 and m[kind+i]==0,'All shot lanes must damage the real arm weak point'
 check('extra-arm-weakpoint' if extra else 'native-arm-weakpoint',arm_damage)
def arm_art():
 for angle in range(16):
  c=machine();m=c.memory;m[0x19]=4;m[0x9c]=4;m[0x9f]=62
  for base in [0,0x30,0x60,0x90]:
   m[0x600+base]=1;m[0x615+base]=angle*4
   for part in range(6):m[0x618+base+part]=40+part*12;m[0x620+base+part]=50+base//3
  call(c,0x8bd9)
  expected=[];at=4
  for _ in range(62-m[0x9f]):
   expected.append(m[0x200+at:0x204+at]);at=(at+0xc4)&255
   if at==0:at=4
  m[0x9c]=4;call(c,H['DrawArms'])
  actual=[m[0x7100+i:0x7104+i] for i in range(4,m[0x9c],4)]
  assert actual==expected,('Native arm tile/flip/palette mismatch',angle)
check('all-sixteen-native-arm-rendering-angles',arm_art)
def collision_equivalence():
 rng=random.Random(15012)
 for scenario in range(200):
  c=machine();m=c.memory;m[0x100]=1;m[0x7005]=1
  for slot in range(9):
   m[0x123+slot]=rng.choice([0,6,7]) if slot<6 else rng.choice([0,8])
   m[0x163+slot]=1 if m[0x123+slot]==7 else (3 if slot>=6 else 0)
   m[0x363+slot]=rng.randrange(256);m[0x323+slot]=rng.randrange(8,200)
  for target in range(10):
   if rng.randrange(2):m[0x30c+target]=0x85;m[0x10c+target]=1;m[0x12c+target]=0x11
   m[0x36c+target]=rng.randrange(256);m[0x32c+target]=rng.randrange(8,200)
   m[0x316+target]=rng.choice([0,1,2]);m[0x136+target]=0x59
   m[0x376+target]=rng.randrange(256);m[0x336+target]=rng.randrange(8,200)
  native=machine();native.memory[:]=m[:]
  call(native,0xbfe2);call(c,H['CombatGate'])
  for start,end in [(0x100,0x180),(0x300,0x380),(0x460,0x500)]:
   assert m[start:end]==native.memory[start:end],('Native collision equivalence',scenario,hex(start))
check('two-hundred-native-shot-collision-comparisons',collision_equivalence)
for slot in range(6):
 def falling(slot=slot):
  c=machine();m=c.memory;m[0x123+slot]=6;m[0x363+slot]=40;m[0x323+slot]=60;m[0x7020+slot]=8
  for t in range(20):
   old=m[0x323+slot];call(c,H['FireLoop'])
   assert m[0x363+slot]==44+t*4 and old<=m[0x323+slot]<=old+4
  assert m[0x323+slot]>110
 check(f'fireball-gravity-slot-{slot}',falling)
 def bounce(slot=slot):
  c=machine();m=c.memory;m[0x123+slot]=6;m[0x363+slot]=40;m[0x323+slot]=104;m[0x7020+slot]=16
  # A floor at terrain row 16: native probe adds 20 to the screen Y.
  for page in [0x500,0x600]:
   for col in range(32):m[page+col*8+4]=3
  call(c,H['FireLoop']);assert m[0x123+slot]==6 and m[0x323+slot]==104 and m[0x7020+slot]==240
  call(c,H['FireLoop']);assert m[0x323+slot]<104 and m[0x123+slot]==6
 check(f'fireball-floor-bounce-slot-{slot}',bounce)
 def wall(slot=slot):
  c=machine();m=c.memory;m[0x123+slot]=6;m[0x363+slot]=40;m[0x323+slot]=80;m[0x7020+slot]=8
  m[0x500:0x700]=[255]*512;call(c,H['FireLoop']);assert m[0x123+slot]==0
 check(f'fireball-wall-slot-{slot}',wall)
def laser():
 c=machine();m=c.memory;m[0x123]=7;m[0x163]=1;m[0x363]=50;m[0x323]=80
 call(c,H['FireLoop']);assert m[0x363]==62 and m[0x323]==80 and m[0x123]==7
check('native-laser-motion',laser)
def double():
 c=machine();m=c.memory;m[0x126]=0x24;m[0x166]=2;m[0x366]=40;m[0x326]=80;m[0x7023]=240
 call(c,H['FireLoop']);assert m[0x326]<80 and m[0x366]==44
check('double-upward-fireball',double)
def native_kill():
 c=machine();m=c.memory;m[0x100]=1;m[0x7005]=1
 m[0x123]=6;m[0x363]=80;m[0x323]=80;m[0x7020]=8
 m[0x30c]=0x85;m[0x10c]=1;m[0x12c]=0x11;m[0x36c]=84;m[0x32c]=82
 call(c,H['FireLoop']);call(c,0xbfe2)
 assert m[0x30c]!=0x85 and m[0x123]==0,'Fireball must kill through the native shot/enemy collision sweep'
check('fireball-native-enemy-kill',native_kill)
def native_boss():
 c=machine();m=c.memory;m[0x100]=1;m[0x7005]=1;m[0x1b]=0x85;m[0x7005]=1
 m[0x315]=0x98;m[0x115]=0x90;m[0x135]=0x6c;m[0x469]=3;m[0x495]=1
 for hit in range(6):
  m[0x123]=6;m[0x163]=0;m[0x363]=80;m[0x323]=80;m[0x7020]=8;m[0x7030]=0
  m[0x375]=84;m[0x335]=89
  call(c,H['FireLoop']);call(c,0xbfe2)
  assert m[0x475]==hit+1,'Native Big Core vulnerability must accept each fireball'
 m[0xa8]=9;call(c,0xb914)
 assert m[0x1b]==0x86 and m[0x315]==2 and m[0x3b]==1,'Six fireball hits must trigger the real boss defeat'
check('fireball-native-big-core-defeat',native_boss)
for inv in [0,1]:
 def death(inv=inv):
  c=machine();m=c.memory;m[0x7005]=inv;m[0x100]=1;m[0x1b]=128;call(c,H['DeathGate'])
  assert m[0x100]==(1 if inv else 2)
 check(f'native-death-gate-{inv}',death)
print('PASS',len(checks),'6502 cases')
(ROOT/'build/cpu-results.json').write_text(json.dumps({'passed':True,'cases':checks},indent=2))
