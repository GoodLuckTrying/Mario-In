"""Native-integration CPU fixtures for the two new ports (never installs)."""
from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from audit_all_physics import execute
from native_port_common import sha

def load(game):
 p=ROOT/game;j=json.loads((p/'build/manifest.json').read_text());m=MPU();data=(p/'dist'/('Mario in Mega Man 2.nes' if game=='megaman2' else 'Mario in Metroid.nes')).read_bytes()
 m.memory[0x8000:0xC000]=data[16+(14 if game=='megaman2' else 1)*16384:16+(15 if game=='megaman2' else 2)*16384]
 m.memory[0xC000:]=data[16+15*16384:16+16*16384]
 if game=='megaman2':
  code=(p/'build/code.bin').read_bytes();m.memory[0x6000:0x6000+len(code)]=code
 else:
  m.memory[0x7400:0x77F0]=(p/'build/code-a.bin').read_bytes();m.memory[0x7900:0x8000]=(p/'build/code-b.bin').read_bytes()
 execute(m,j['labels']['Init'])
 return m,j,data

def main():
 groups={'megaman2':[],'metroid':[]}
 def check(game,name,cases):groups[game].append(dict(name=name,cases=cases,passed=True))
 for game in groups:
  m,j,data=load(game);original=Path(j['base_rom']).read_bytes();bank=0 if game=='megaman2' else 6;base=0x1000 if game=='megaman2' else 0
  for tile in j['protected_tiles']:
   off=16+bank*16384+base+tile*16
   assert data[off:off+16]==original[off:off+16],(game,'shared CHR',tile)
  check(game,'All source-identified shared pickup, weapon and native object CHR tiles preserved',len(j['protected_tiles']))
  if game=='megaman2':
   tables=[k for k in j['native'] if k.startswith('weapon_dmg_')]
   for k in tables:
    off=16+15*16384+j['native'][k]-0xC000
    assert data[off:off+0x78]==original[off:off+0x78],('native damage table',k)
   check(game,'Native enemy weapon immunities and damage tables retained',len(tables))
 # Native weapons keep the original dispatch, objects, hitboxes and ammo system.
 expected=[0x23,0x30,0x31,0x32,0x33,0x34,0x37,0x36,0x35,0x38,0x39,0x3A]
 weapon_cases=0
 for weapon in range(12):
  for facing in (0,64):
   c,j,data=load('megaman2');n=j['native'];h=j['labels'];v=c.memory
   v[0x2c]=6;v[0xA9]=weapon;v[0x23]=v[0x27]=2;v[0x420]=0x80|facing;v[0x460]=128;v[0x4a0]=128;v[0x6c0]=28
   for i in range(11):v[n['weapon_ammo']+i]=28
   execute(c,n['fire_weapon_dispatch'],{n['sound_queue_push']:lambda c:None})
   types=[v[0x400+i] for i in range(2,16) if v[0x420+i]&128]
   assert expected[weapon] in types,('native weapon',weapon,types,expected[weapon])
   # The default pellet retains its original straight trajectory.
   if weapon==0:
    slot=next(i for i in range(2,16) if v[0x420+i]&128)
    assert v[0x600+slot]==4 and v[0x640+slot]==0 and v[0x660+slot]==0
   weapon_cases+=1
 check('megaman2','All 12 native weapon/utility selections spawn the correct native object in both directions',weapon_cases)
 # Every selected weapon fires alongside, rather than being replaced by, Mario's
 # private slots. Filling the three native pellet slots cannot consume those.
 for weapon in range(12):
  for facing in (0,64):
   c,j,data=load('megaman2');n=j['native'];h=j['labels'];v=c.memory
   v[0x2c]=6;v[0xA9]=weapon;v[0x23]=v[0x27]=2;v[0x420]=0x80|facing;v[0x460]=128;v[0x4a0]=128;v[h['M_HELD']]=64
   for i in range(11):v[n['weapon_ammo']+i]=28
   execute(c,h['FireSpawn'],{n['sound_queue_push']:lambda c:None})
   execute(c,n['fire_weapon_dispatch'],{n['sound_queue_push']:lambda c:None})
   assert v[0x427]&128 and v[0x407]==0x23 and v[0x607]==4 and v[0x647]==255 and v[0x667]==128
   assert expected[weapon] in [v[0x400+i] for i in range(2,6) if v[0x420+i]&128]
 check('megaman2','Independent Mario shots coexist with all 12 selected guns/items in both facings',24)
 # Compare selected-weapon damage against the unmodified engine, including the
 # partially replaced LDY/LDA instruction boundaries in both dispatchers.
 dispatch_cases=0
 for boss in (False,True):
  for weapon in range(9):
   c,j,data=load('megaman2');n=j['native'];h=j['labels'];v=c.memory;orig=Path(j['base_rom']).read_bytes()
   bank=11 if boss else 14
   v[0x8000:0xC000]=data[16+bank*16384:16+(bank+1)*16384]
   for addr,val in {0xA9:weapon,0x2b:16,0x410:0x17,0x430:0x83,0x6d0:20,0x6f0:0,0x422:0x81,0x4e2:2,0xB3:0,0xB4:0,0x421:0x80,0x6c1:28}.items():v[addr]=val
   ref=MPU();ref.memory[:]=v[:];ref.memory[0x8000:0xC000]=orig[16+bank*16384:16+(bank+1)*16384];ref.memory[0xC000:]=orig[16+15*16384:]
   c.x=ref.x=2
   target=n['weapon_boss_hit_dispatch'] if boss else n['weapon_collision_dispatch']
   traps={n['sound_queue_push']:lambda c:None}
   execute(c,target,traps);execute(ref,target,traps)
   for addr in [0x422,0x642,0x602,0x430,0x6d0,0x6f0,0xB4,0x6c1]:assert v[addr]==ref.memory[addr],('native damage dispatch',boss,weapon,hex(addr),v[addr],ref.memory[addr])
   assert c.p&1==ref.p&1
   dispatch_cases+=1
 check('megaman2','Original selected-weapon enemy/boss damage dispatch matches original ROM',dispatch_cases)
 for boss in (False,True):
  for weapon in range(12):
   c,j,data=load('megaman2');n=j['native'];h=j['labels'];v=c.memory
   if boss:v[0x8000:0xC000]=data[16+11*16384:16+12*16384]
   for addr,val in {0xA9:weapon,0x2b:16,0x410:0x17,0x430:0x83,0x6d0:20,0x6f0:0,0x427:0x81,0xB3:0,0xB4:0,0x421:0x80,0x6c1:28}.items():v[addr]=val
   c.x=7
   execute(c,h['BossWeaponDispatch' if boss else 'WeaponDispatch'],{n['sound_queue_push']:lambda c:None})
   assert v[0x6c1 if boss else 0x6d0]<(28 if boss else 20)
   assert v[0xA9]==weapon,'fireball must not change selected native weapon'
 check('megaman2','Mario fireballs use buster damage independently of all selected weapons, including bosses',24)
 for kind in ('crawler','rio','mellow'):
  c,j,data=load('metroid');n=j['native'];h=j['labels'];v=c.memory;c.x=16 if kind!='mellow' else 0
  for addr,val in {0x301:15,0x30c:0,h['M_VY']:2,0x6c8c:104,0x11:4}.items():v[addr]=val
  c.p&=~1
  if kind=='mellow':
   v[n['Mellows_0_y']]=128;v[n['Mellows_0_hi']]=0
   execute(c,h['MellowContactGate'])
   assert v[n['Mellows_0_isHit']]!=0
  else:
   for addr,val in {0x6b04:2,0x6b05:8,0x41b:4,0x6b12:5 if kind=='crawler' else 6,0x410:132}.items():v[addr]=val
   execute(c,h['ContactGate'])
   assert v[0x41e]==0x81 and v[0x414]&32
  assert v[h['M_VY']]==0xFC and v[0x6c8d]==8
 check('metroid','Crawler, swooper and Mellow stomps route through native defeat flags and share bounce grace',3)
 # Native enemies and native objects share the renderer and slot numbers.
 # Compare actual OAM against the original across all six enemy slots, with
 # both fireball objects live, both player forms and both enemy facings.
 render_cases=0
 for slot in range(0,0x60,0x10):
  for form in (2,3):
   for facing in (0,1):
    for frame in ('ZoomerOnFloor0','Rio0','Skree0','Ripper_R'):
     c,j,data=load('metroid');n=j['native'];h=j['labels'];v=c.memory;orig=Path(j['base_rom']).read_bytes()
     for key in ('EnFramePtrTable1','EnFramePtrTable2','EnPlacePtrTable'):
      addr=n['AreaPointers_RAM_'+key];value=n[key+'_BANK1'];v[addr]=value&255;v[addr+1]=value>>8
     for addr,val in {n['PageIndex']:slot,n['IsSamus']:0,n['MainRoutine']:3,n['ScrollDir']:2,n['PPUCTRL_ZP']:0,n['SpritePagePos']:0,0x300:form,0x350:1,0x3c0:1,0x400+slot:120,0x401+slot:100,0x405+slot:facing,0x6af7+slot:n['_id_EnFrame_'+frame+'_BANK1'],0x6afb+slot:0}.items():v[addr]=val
     ref=MPU();ref.memory[:]=v[:];ref.memory[0xc000:]=orig[16+7*16384:]
     execute(ref,n['DrawEnemy']);execute(c,n['DrawEnemy'])
     assert v[0x200:0x300]==ref.memory[0x200:0x300],('enemy OAM changed',slot,form,facing,frame)
     assert v[n['SpritePagePos']]==ref.memory[n['SpritePagePos']]
     render_cases+=1
 check('metroid','All six enemy slots retain original OAM across four species, both facings/forms and live fireball slots',render_cases)
 # Stomps, neighbors, shield/spike exclusions and original contact damage.
 cases=0
 for dx in range(-18,19,3):
  c,j,data=load('megaman2');h=j['labels'];n=j['native'];v=c.memory;x=16
  for a,val in {0x2c:6,0x2b:x,0x420+x:0x83,0x400+x:0x17,0x6e0+x:0,0x6c0+x:20,0x4a0+x:128,0x2d:80+dx,0x2e:80,0x4a0:110,0x7018:104,h['M_VY']:2,0x6c0:28}.items():v[a]=val
  c.x=x;execute(c,h['ContactGate'],{n['item_drop_rng']:lambda c:None})
  assert v[0x400+x]==6 and v[0x6c0+x]==0 and v[0x6c0]==28 and v[h['M_VY']]==0xFC
  # A neighboring ordinary enemy may overlap the following ascending frame.
  x=17;v[0x400+x]=0x17;v[0x420+x]=0x83;v[0x6e0+x]=0;v[0x6c0+x]=20;v[0x4a0+x]=128
  c.x=x;execute(c,h['ContactGate'])
  assert v[0x6c0]==28 and v[0x6c0+x]==20
  cases+=2
 for typ,flag,vy,y in [(0x17,0x83,0xFC,110),(0x46,0x83,2,110),(0x17,0x8B,2,110),(0x17,0x83,0,128)]:
  c,j,data=load('megaman2');h=j['labels'];n=j['native'];v=c.memory;x=16
  for a,val in {0x2c:6,0x2b:x,0x420+x:flag,0x400+x:typ,0x6e0+x:0,0x6c0+x:20,0x4a0+x:128,0x2d:80,0x2e:80,0x4a0:y,0x7018:y,h['M_VY']:vy,0x6c0:28}.items():v[a]=val
  c.x=x;execute(c,h['ContactGate'],{n['player_damage_knockback']:lambda c:None})
  assert v[0x6c0]<28 and v[0x6c0+x]==20,('unsafe contact',typ,flag,vy,y)
  cases+=1
 check('megaman2','Descending stomps precede damage; neighbors have bounce grace; ascending, side, shield and spiked contacts remain dangerous',cases)
 # Ride forces are added by the original conveyor/platform routine.
 for facing,dest in [(64,129),(0,127)]:
  c,j,data=load('megaman2');h=j['labels'];v=c.memory
  for a,val in {0x460:128,0x420:0xC0,0x40:1,0xAF:facing}.items():v[a]=val
  # Native scroll_lock addresses come from the disassembly, rather than guessed camera fields.
  v[j['native']['scroll_lock_lo']]=0;v[j['native']['scroll_lock_hi']]=1
  def horiz(c):
   v[0x460]=(v[0x460]+(1 if v[0x42]&64 else -1))&255
  execute(c,h['Horizontal'],{j['native']['player_horiz_movement']:horiz})
  assert v[0x460]==dest and v[h['M_SMB_X_SPEED']]==0
 check('megaman2','Native left/right conveyor carry is independent of Mario momentum',2)
 # NMI fault injection: interrupt every byte of native MMC1 transaction code.
 nmi_cases=0
 for pc in [0x4000,*range(0xC4B6,0xC510)]:
  c,j,data=load('metroid');h=j['labels'];n=j['native'];v=c.memory
  c.pc=pc;c.sp=0xD0;c.a=0x52;c.x=0x36;c.y=0x79;c.p=0x65;v[0]=0xAD;v[1]=0x6C;v[0x1A]=0;v[0x1D]=0
  def scratch(c):v[0]=0xAA;v[1]=0xBB
  names=['NMIScreenWrite','CheckPaletteWrite','CheckVRAMStructBufferWrite','WritePPUCtrl','WriteScroll','ReadJoyPads','SoundEngine','UpdateAge']
  traps={n[k]:scratch for k in names}
  c.nmi()
  for step in range(10000):
   if c.pc==pc:break
   if c.pc in traps:traps[c.pc](c);c.pc=0x5FFE;v[0x5FFE]=0x60
   c.step()
  else:raise AssertionError(('NMI return',pc,c.pc))
  assert (c.a,c.x,c.y,c.sp)==(0x52,0x36,0x79,0xD0)
  assert v[0]==0xAD and v[1]==0x6C
  assert v[0x1A]==(1 if pc==0x4000 else 0),('MMC1 deferral',pc,v[0x1A])
  nmi_cases+=1
 check('metroid','NMI preserves registers/scratch RAM and defers mirroring while every native MMC1 transaction byte is interrupted',nmi_cases)
 for game,checks in groups.items():
  j=json.loads((ROOT/game/'build/manifest.json').read_text())
  report=dict(rom_sha256=j['output_sha256'],passed=True,checks=checks)
  (ROOT/game/'build/cpu-verification.json').write_text(json.dumps(report,indent=2))
  print('PASS',game,sum(c['cases'] for c in checks),'native CPU/CHR cases')
if __name__=='__main__':main()
