"""Native wall/rope handoffs and actual Zelda/Rygar 6502 shot comparison."""
from pathlib import Path
import hashlib,json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from verify_physics import run,set_values
P=ROOT/'rygar'
def main():
 m=json.loads((P/'build/manifest.json').read_text());h=m['labels'];rom=(P/'dist/Mario in Rygar.nes').read_bytes();n=0
 zmeta=json.loads((ROOT/'zelda/build/manifest.json').read_text());z=zmeta['labels'];zraw=(ROOT/'zelda/dist/Mario in The Legend of Zelda.nes').read_bytes()
 assert hashlib.sha256(rom).hexdigest()==m['output_sha256']
 assert hashlib.sha256(zraw).hexdigest()==zmeta['output_sha256']
 def cpu():
  c=MPU();c.memory[0x6000:0x8000]=rom[16+8*16384:16+8*16384+8192];c.memory[0x8000:0xc000]=rom[16+5*16384:16+6*16384];c.memory[0xc000:]=rom[16+15*16384:]
  return c
 def zelda():
  c=MPU();raw=zraw[16:];c.memory[0x8000:0xc000]=raw[:16384];c.memory[0xc000:]=raw[7*16384:]
  for name,bank in [('01_CODE',1),('06_DATA',6)]:
   at=z['__BANK_'+name+'_LOAD__'];dest=z['__BANK_'+name+'_RUN__'];size=z['__BANK_'+name+'_SIZE__'];off=bank*16384+at-0x8000;c.memory[dest:dest+size]=raw[off:off+size]
  c.memory[0x6530:0x67f0]=[0x26]*0x2c0
  set_values(c,{z['GameMode']:5,z['M_MODE']:5,z['IsUpdatingMode']:1,z['M_TTL']:96,z['M_X']:120,z['M_Y']:128})
  return c
 for direction,zd in enumerate([1,2,4,8]):
  for fraction in range(0,256,16):
   c=cpu();ref=zelda()
   set_values(c,{0x492:0x80,h['FB']:1,h['FB']+1:120,h['FB']+2:128,h['FB']+6:direction,h['FB']+7:1,h['FB']+9:fraction})
   c.memory[0x38a:0x40e]=[255]*132 # Native overhead walkable ground.
   set_values(ref,{z['M_DIR']:zd,z['M_FRAC']:fraction})
   for tick in range(20):
    run(c,h['FireUpdate']);run(ref,z['MarioFireUpdate'])
    actual=[c.memory[h['FB']+i]for i in [1,2,8,9]]
    expected=[ref.memory[z[k]]for k in ['M_X','M_Y','M_PHASE','M_FRAC']]
    assert c.memory[h['FB']]>0 and actual==expected,('Zelda projected bounce',direction,fraction,tick,actual,expected)
    n+=1
 # Side-only/ceiling contacts must not cancel falling or reversal; floor
 # support and approaching walls still resolve through the native response.
 for mask in [1,2,4,8,9,10,5,6,15]:
  for vy in [0,3,253]:
   for vx in [0,24,232]:
    c=cpu();set_values(c,{0x7d31:1,h['M_STATE']:2,h['M_VY']:vy,h['M_SMB_X_SPEED']:vx,9:mask,10:0,11:0,0xff:0})
    run(c,h['Response'])
    if mask==1 and vy<128:assert c.memory[h['M_VY']]==vy and c.memory[h['M_STATE']]==2,'ceiling cannot ground a descending player'
    if mask==2 and vy<128:assert c.memory[h['M_STATE']]==0,'native floor contact supports a descending player'
    if mask==8 and vx>=128:assert c.memory[h['M_SMB_X_SPEED']]==vx,'leftward motion escapes a right wall'
    if mask==4 and 0<vx<128:assert c.memory[h['M_SMB_X_SPEED']]==vx,'rightward motion escapes a left wall'
    assert c.memory[0x100]==c.memory[9],'collision application uses the filtered contact'
    n+=1
 for action in [0x20,0x28,0x30,0x38,0x40,0x48,0x50,0x68]:
  for held in [1,2,4,8]:
   c=cpu();set_values(c,{0x7d00:0x4d,0x7d5a:0,0x1c:0,0x492:0x84,0x4b2:action,0x28:held,0x4c2:224,0x4d2:32,0x4f2:140,0x512:96,0x4e2:80,0x502:160})
   ref=MPU(memory=c.memory.copy());ref.x=0;ref.p&=254;run(ref,0x962b)
   run(c,h['BeginStep'])
   assert c.memory[4:8]==ref.memory[4:8]and c.memory[0x7d31]==0,'native no-gravity tool states keep native integration'
   n+=1
 report=dict(rom_sha256=m['output_sha256'],passed=True,cases=n,zelda_reference_sha256=zmeta['output_sha256'],scope='1,280 update comparisons with assembled Zelda fireball code; native directional contact and rope/grapple handoffs under 6502 execution. Camera and enemy contacts are isolated here; Mesen fixtures cover their integration.')
 (P/'build/traversal-results.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS Rygar traversal and Zelda projectile comparison:',n,'cases')
if __name__=='__main__':main()
