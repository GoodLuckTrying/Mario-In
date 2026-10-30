"""Execute movement, gravity, power and projectile rules on real 6502 code."""
from pathlib import Path
import hashlib,json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'tools'))
from verify_physics import run,set_values
m=json.loads((ROOT/'build/manifest.json').read_text());H=m['labels']
rom=(ROOT/'dist/SMB1 Mario and Luigi in Super Mario Bros 2.nes').read_bytes()
original=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[16:0x8010]
ref=json.loads((ROOT.parent/'tests/smb-reference-symbols.json').read_text())['labels']
def fresh(bank=3):
    c=MPU();c.memory[0x8000:0xc000]=rom[16+bank*0x4000:16+(bank+1)*0x4000];c.memory[0xc000:]=rom[16+7*0x4000:16+8*0x4000]
    c.memory[0x7e13]=0x70;c.memory[0x7e20]=0x70
    return c
def call(c,name,a=0):
    c.a=a;c.sp=255;c.stPushWord(0x5ffe);c.pc=H[name];start=c.processorCycles
    for _ in range(30000):
        if c.pc==0x5fff:return c.processorCycles-start
        c.step()
    raise AssertionError((name,hex(c.pc)))
checks=[]
def passed(name,cases):
    checks.append({'name':name,'passed':True,'cases':cases});print(name,cases,'PASS',flush=True)
n=0
for character in [0,3]:
 for small in [0,1]:
  for direction in [1,2]:
   for kind in ['walk','run','release','reverse','air-neutral','air-turn']:
    c=fresh();s=MPU();s.memory[0x8000:]=original
    set_values(s,{0x33:direction,0x45:direction,0x74e:1,0xe:8,0x754:small,0x490:3,0x86:96,0xce:144,0x70a:0x70})
    set_values(c,{H['CurrentCharacter']:character,H['PlayerCurrentSize']:small,H['PlayerDirection']:int(direction==1),H['PlayerMovementDirection']:direction})
    for tick in range(100):
        held=direction|(0 if kind=='walk'else 64)
        if kind=='release'and tick>=40:held=0
        if kind=='reverse'and tick>=40:held=(direction^3)|64
        if kind=='air-neutral'and tick>=20:held=0
        if kind=='air-turn'and tick>=20:held=(direction^3)|64
        air=kind.startswith('air')and tick>=20
        set_values(s,{0xa:held&0xc0,0xb:0,0xc:held&3,0x6fc:held,0x1d:2 if air else 0})
        if s.memory[0x783]:s.memory[0x783]-=1
        set_values(c,{H['Player1JoypadHeld']:held,H['Player1JoypadPress']:0,H['PlayerInAir']:int(air)})
        run(s,ref['PlayerMovementSubs']);call(c,'MarioControl')
        pairs=[(0x57,H['PlayerXVelocity']),(0x705,0x7e01),(0x700,0x7e02),(0x703,0x7e03),(0x783,0x7e04)]
        diff=[(hex(a),s.memory[a],c.memory[b])for a,b in pairs if s.memory[a]!=c.memory[b]]
        assert not diff,(character,small,direction,kind,tick,diff)
        for cpu,address in [(s,0x57),(c,H['PlayerXVelocity'])]:
            if cpu.memory[address]:cpu.memory[0x45 if cpu is s else H['PlayerMovementDirection']]=2 if cpu.memory[address]>=128 else 1
        n+=1
passed('SMB1 horizontal acceleration, run limits, friction, reversal and air steering match original instructions for both brothers and sizes',n)
for velocity in range(256):
    c=fresh();set_values(c,{H['PlayerYVelocity']:velocity,H['PlayerInAir']:1,H['PlayerYLo']:144})
    call(c,'MarioGravity')
    s=MPU();s.memory[0x8000:]=original
    v=velocity if velocity<128 else velocity-256
    set_values(s,{0x9f:v//16,0x433:(velocity&15)*16,0xce:144,0x00:0x70,0x02:4})
    s.a=0;s.x=0;run(s,ref['ImposeGravity'])
    call(c,'MarioApplyY')
    assert(c.memory[0x7e11],c.memory[0x7e12],c.memory[H['PlayerYLo']],c.memory[H['PlayerYSubpixel']])==(s.memory[0x9f],s.memory[0x433],s.memory[0xce],s.memory[0x416]),velocity
passed('all native vertical collision velocities import into exact SMB1 position/fraction/gravity instructions',256)
peaks=[]
for hold in [1,25]:
    c=fresh();set_values(c,{H['PlayerDirection']:1,H['PlayerMovementDirection']:1,H['PlayerYLo']:144})
    peak=144
    for tick in range(100):
        c.memory[H['Player1JoypadHeld']]=128 if tick<hold else 0
        c.memory[H['Player1JoypadPress']]=128 if tick==0 else 0
        call(c,'MarioGravity');call(c,'MarioControl');call(c,'MarioApplyY')
        position=c.memory[H['PlayerYLo']]+256*c.memory[H['PlayerYHi']]
        peak=min(peak,position)
    peaks.append(144-peak)
assert peaks==[24,64],peaks
passed('tap and held jumps reproduce exact SMB1 24/64-pixel apexes with full-precision integration',200)
for character in [0,3]:
 for small in [0,1]:
  c=fresh(1);set_values(c,{H['CurrentCharacter']:character,H['PlayerCurrentSize']:small,H['PlayerHealth']:15 if small else 31,H['Player1JoypadPress']:64,H['PlayerXLo']:120,H['PlayerYLo']:80,H['IsHorizontalLevel']:1})
  for _ in range(3):call(c,'MarioFireSpawn')
  active=[i for i in range(9)if c.memory[0x7e40+i]]
  assert len(active)==(0 if small else 2)
  for i in active:assert c.memory[H['ObjectType']+i]==0x32 and c.memory[H['ObjectProjectileTimer']+i]==1
passed('only big forms fire, each brother has two shots and each shot uses an initialized native projectile slot',4)
for health in [15,31,47,63]:
    c=fresh(1);set_values(c,{H['PlayerHealth']:health,H['PlayerScreenX']:120,H['SpriteTempScreenX']:130,H['byte_RAM_12']:0})
    call(c,'DamagePlayer')
    if health==15:assert c.memory[H['PlayerState']]==7
    else:assert c.memory[H['PlayerHealth']]==health-16 and c.memory[H['DamageInvulnTime']]==127
passed('native heart damage, extra-heart protection and last-heart death remain intact',4)
for side in range(256):
    c=fresh(1);set_values(c,{H['PlayerHealth']:63,H['PlayerScreenX']:128,H['SpriteTempScreenX']:side,H['byte_RAM_12']:0})
    call(c,'DamagePlayer')
    vx=c.memory[H['PlayerXVelocity']];vx=vx if vx<128 else vx-256
    assert -24<=vx<=24 and (vx>=0 if side<=128 else vx<=0),(side,vx)
    assert c.memory[H['PlayerYVelocity']]==192 and c.memory[H['PlayerInAir']]==1
passed('extra-heart hurt knockback stays bounded, points away from contact and preserves the native upward reaction',256)
for frame in range(1,6):
    if frame==1:
        c=fresh(2);c.memory[H['M_FIRE_SOUND']]=5
    call(c,'ProcessSoundEffectQueue1')
    assert c.memory[H['M_FIRE_SOUND']]==5-frame
    assert c.memory[H['SoundEffectPlaying1']]==(8 if frame<5 else 0)
    if frame==1:assert [c.memory[a]for a in [0x4004,0x4005,0x4006,0x4007]]==[0x9a,0x99,0x3a,0x0a]
assert c.memory[0x4004]==0x90 and c.memory[0x4005]==0x7f
c=fresh(2);set_values(c,{H['M_FIRE_SOUND']:5,H['SoundEffectQueue1']:4});call(c,'ProcessSoundEffectQueue1')
assert c.memory[H['M_FIRE_SOUND']]==0 and c.memory[H['SoundEffectPlaying1']]==4
passed('five-frame fireball chirp releases the music channel and defers to native queued effects',6)
for enemy,mouth,cooldown,expected in [(0x1c,0,0,1),(0x1c,0,32,2),(0x2c,0,0,2),(0x2c,1,0,1),(0x2c,1,32,2)]:
    c=fresh(1);set_values(c,{H['ObjectType']:enemy,H['EnemyHP']:2,H['ObjectTimer1']:mouth,H['ObjectFlashTimer']:cooldown,H['byte_RAM_12']:8,H['byte_RAM_ED']:1,0x7e48:96,H['EnemyState']+8:1,H['ObjectType']+8:0x32})
    c.x=1;call(c,'MarioFireHit')
    assert c.memory[H['EnemyHP']]==expected,(enemy,mouth,cooldown,c.memory[H['EnemyHP']])
    assert c.memory[0x7e48]==0 and c.memory[H['EnemyState']+8]==0,'a hit consumes its fireball'
passed('native boss HP, hit cooldowns and Wart closed/open mouth rules remain enforced for fireballs',5)
(ROOT/'build/cpu-verification.json').write_text(json.dumps({'rom_sha256':hashlib.sha256(rom).hexdigest(),'checks':checks},indent=2))
