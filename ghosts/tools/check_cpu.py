"""Instruction fixtures for native hooks; terrain and scripts stay separate."""
from pathlib import Path
import hashlib,json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'ghosts';sys.path.insert(0,str(ROOT/'tools'))
from audit_all_physics import execute
j=json.loads((P/'build/manifest.json').read_text());H=j['labels'];N=j['native'];rom=(P/'dist/Mario in Ghosts n Goblins.nes').read_bytes();base=Path(j['base_rom']).read_bytes();checks=[]
def fresh(original=False):
 c=MPU();r=base if original else rom;c.memory[0x8000:0xc000]=r[16+4*16384:16+5*16384];c.memory[0xc000:]=r[-16384:]
 if not original:
  c.memory[0x6000:0x8000]=rom[16+8*16384:16+8*16384+8192];execute(c,H['Init'])
 return c
def put(c,d):
 for a,v in d.items():c.memory[a]=v&255
# The native armor stream advances past Mario's private body tiles while
# retaining the armor pickup and frog ranges and its source cursor semantics.
for dst in range(0x200,0x360,32):
 original=fresh(True);port=fresh()
 for c in (original,port):
  put(c,{0x24:dst&255,0x25:dst>>8,0x26:0xf0,0x27:0xb4,0x22:1,0x23:32,0x31:0});c.x=3;c.y=7
 execute(original,0xeecf);execute(port,H['QueueBody'])
 for address in (0x24,0x25,0x26,0x27):assert port.memory[address]==original.memory[address]
 assert (port.x,port.y)==(3,7)
 if 0x220<=dst<0x2a0:assert port.memory[0x31]==0,'retired body chunk must not reach the PPU queue'
 else:assert bytes(port.memory[0x720:0x744])==bytes(original.memory[0x720:0x744])
checks.append(dict(name='Armor-loss CHR queue preserves Mario buffers while retaining native armor/frog transfers and source progression',cases=11,passed=True))
c=fresh();put(c,{0x4f0:0x90});execute(c,H['FloorProbe']);assert c.p&1
checks.append(dict(name='Native moving-platform support counts as floor without querying the background map',cases=1,passed=True))
count=0
private_tiles=set(range(0x22,0x2a))|set(range(0x38,0x42))
for frame in list(range(0x16,0x20))+list(range(0x36,0xfe)):
 for attr in (0,1,2,3,0x40,0x80):
  original=fresh(True);port=fresh();outputs=[]
  for c in (original,port):
   put(c,{0x29:0x80,0x2a:4,0x2b:0,0x2c:2,0x480:100,0x481:frame,0x482:attr,0x483:100,0x484:255,0x485:255,0x486:255,0x487:255})
   execute(c,0x80d0);outputs.append(bytes(c.memory[0x200:0x400]))
  assert outputs[0]==outputs[1],('native meta sprite changed',frame,attr)
  end=original.memory[0x2b]+256*original.memory[0x2c]-0x200
  assert not set(outputs[0][1:end:4]) & private_tiles,('CHR ownership overlap',frame,attr)
  count+=1
checks.append(dict(name='210 non-player/menu/equipment meta frames with six palette/flip controls match original OAM and avoid retired Arthur CHR; native HUD font stays separate',cases=count,passed=True))
count=0
for form in (0,32):
 for direction in (1,2):
  for kind in (0,1,2,3,4,6,7,8,10):
   c=fresh();m=c.memory
   put(c,{H['M_LIVE']:1,H['M_FORM']:form,H['M_STATE']:1,H['M_VY']:3,H['M_PREV_Y']:156,0x4f0:0x80|form,0x4f1:0xa2,0x631+1:kind,0x509:160,0x50a:180,0x554:100,0x555:104,0x599:160,0x59a:180,0x5af:100,0x5b0:104,0x5f1:4 if direction==1 else 12,0x26:8,0x27:12})
   c.x=1;execute(c,H['WeaponHit']);assert m[0x648]==1 and m[H['M_VY']]==0xfc and m[H['M_GRACE']]==8 and not m[0x4f0]&1
   # Adjacent enemy is harmless during the bounce grace.
   m[0x4f2]=0xa2;m[0x633]=kind;m[0x50b]=180;m[0x556]=108;m[0x5b1]=108;c.x=2
   execute(c,H['ContactGate']);assert not c.p&1
   count+=1
checks.append(dict(name='Both forms/facings stomp nine ordinary enemy kinds, bounce and protect against adjacent contact',cases=count,passed=True))
count=0
for kind in (5,9,0x12,0x15,0x1f,0x22,0x2d):
 c=fresh();m=c.memory;put(c,{H['M_LIVE']:1,H['M_STATE']:1,H['M_VY']:3,H['M_PREV_Y']:156,0x4f0:0x80,0x4f1:0x80,0x632:kind,0x509:160,0x50a:180,0x554:100,0x555:100,0x599:160,0x5af:100,0x5b0:100,0x26:8,0x27:12})
 c.x=1;execute(c,H['WeaponHit']);assert m[0x648]==0 and m[H['M_GRACE']]==0;count+=1
checks.append(dict(name='Bosses, native projectiles, pickups and progression objects cannot be stomped',cases=count,passed=True))
for form in (0,32):
 for direction in (1,2):
  c=fresh();m=c.memory;put(c,{H['M_FORM']:form,H['M_FACING']:direction,H['M_HELD']:64,0x599:184,0x5af:128})
  def empty(c):c.a=0;c.p=(c.p&~0x83)|2
  execute(c,H['FireUpdate'],{N['BgPoint']:empty});assert bool(m[H['FB']])==(form==0)
  if form==0:
   assert m[H['FB']+5]==(1 if direction==1 else 255)
   for _ in range(5):execute(c,H['FireUpdate'],{N['BgPoint']:empty})
   assert m[H['FB']+16]==0,'held B repeats private shots'
   m[H['M_PREV']]=0;execute(c,H['FireUpdate'],{N['BgPoint']:empty});assert m[H['FB']+16]>0
   m[H['M_PREV']]=0;old=bytes(m[0x500:0x700]);execute(c,H['FireUpdate'],{N['BgPoint']:empty});assert bytes(m[0x500:0x700])==old
checks.append(dict(name='Two private shots, fresh B edges, both directions, no small-form shots and no native weapon/state writes',cases=4,passed=True))
count=0
for ex,ep,ey,eyp,bx,bp,by,byp,hit in (
 (255,0,100,0,1,1,100,0,True),(1,1,100,0,255,0,100,0,True),
 (100,0,239,0,100,0,1,1,True),(100,0,1,1,100,0,239,0,True),
 (100,0,100,0,100,1,100,0,False),(100,0,100,0,100,0,100,1,False)):
 c=fresh();m=c.memory;put(c,{0x5b0:ex,0x584:ep,0x59a:ey,0x56e:eyp,0x26:8,0x27:12,H['FB']:20,H['FB']+1:bx,H['FB']+2:bp,H['FB']+3:by,H['FB']+4:byp})
 c.x=1;execute(c,H['FireCollision']);assert bool(c.p&1)==hit,('world seam',ex,ep,ey,eyp,bx,bp,by,byp);count+=1
checks.append(dict(name='Independent fireball hits across X and 240-pixel Y seams, with distant-page rejection',cases=count,passed=True))
c=fresh();m=c.memory;put(c,{0x599:10,0x56d:0});calls=[]
def bg(c):calls.append(1);c.a=0
c.a=0xe7;execute(c,H['PointY'],{N['BgPoint']:bg});assert c.a==0xc6 and not calls and m[0x77]==0
for tile,x,stage,solid in ((0x76,0,0,False),(0x76,8,0,True),(0x77,0,0,True),(0x77,8,0,False),(0x76,8,1,False),(0xc6,0,1,True),(0x10,0,0,False)):
 c.a=tile;m[0x74]=x;m[0xcf]=stage;execute(c,H['FireFloor']);assert bool(c.p&1)==solid
checks.append(dict(name='World-top head probe is bounded and fireballs retain native half-bridge floor rules',cases=8,passed=True))
count=0
for slot in (0,16):
 for direction in (1,255):
  c=fresh();m=c.memory;ball=H['FB']+slot
  put(c,{ball:60,ball+1:128,ball+3:180,ball+5:direction,ball+6:1})
  def floor(c):c.a=0xc6 if m[0x73]>=184 else 0;c.p=(c.p&~0x83)|(0x80 if c.a&128 else 0)|(2 if c.a==0 else 0)
  execute(c,H['FireUpdate'],{N['BgPoint']:floor})
  assert m[ball+6]==0xfd,'floor collision must give the native -3 upward impulse'
  start=m[ball+3];ys=[]
  for _ in range(24):
   execute(c,H['FireUpdate'],{N['BgPoint']:floor});ys.append(m[ball+3])
  height=start-min(ys)
  assert 12<=height<=18,('fireball bounce must be a short SMB-sized hop',slot,direction,height)
  assert any(y>=start for y in ys[10:]),'fireball returns to the floor without a long float'
  assert m[ball]>0,'normal floor bounce must not consume the shot'
  count+=1
checks.append(dict(name='Both private fireballs/facings bounce 12-18 pixels and return to the floor within 24 updates',cases=count,passed=True))
report=dict(rom_sha256=hashlib.sha256(rom).hexdigest(),passed=True,checks=checks)
(P/'build/cpu-verification.json').write_text(json.dumps(report,indent=2));print('PASS native CPU fixtures',sum(x['cases']for x in checks))
