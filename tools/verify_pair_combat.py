"""Execute actual patched/native combat routines, preserving native HP rules."""
from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from verify_physics import run,set_values

def main(game):
 p=ROOT/game;m=json.loads((p/'build/manifest.json').read_text());h=m['labels'];raw=(p/'dist'/f'Mario in {game.capitalize()}.nes').read_bytes();n=0
 def cpu():
  c=MPU();start=16+(16*8192 if game=='karnov'else 8*16384);c.memory[0x6000:0x8000]=raw[start:start+8192]
  c.memory[0xC000:]=raw[16+15*16384:16+16*16384]
  if game=='rygar':c.memory[0x8000:0xC000]=raw[16+5*16384:16+6*16384]
  return c
 if game=='karnov':
  traps={0xC76E:lambda c:None,0xC81D:lambda c:None}
  for mode in ['descending','ascending','side','ground','protected-pair','boss']:
   c=cpu();set_values(c,{0x7d31:1,0x7d01:2,0x7d14:3,0x7d18:100,0x63:128,0x64:103,0x650:0x80,0x651:4,0x652:128,0x653:110})
   if mode=='ascending':c.memory[0x7d14]=252
   if mode=='side':c.memory[0x64]=130;c.memory[0x7d18]=130
   if mode=='ground':c.memory[0x7d01]=0
   if mode=='protected-pair':c.memory[0x7d14]=253;c.memory[0x7d19]=4
   if mode=='boss':c.memory[0x650]=0x89
   run(c,h['ContactGate'],traps)
   if mode in ['descending','protected-pair']:
    assert c.memory[0x651]&15==2,mode+' native death state'
    assert c.memory[0x7d14]==253 and c.memory[0x64]==102,mode+' stomp bounce'
    assert c.memory[0x68]==0,mode+' must not damage Mario'
   else:assert c.memory[0x651]&15!=2,mode+' must not stomp'
   n+=1
  c=cpu();set_values(c,{0x650:0x80,0x651:4,0x7e00:1,0x7e01:128,0x7e02:130,0x65:8})
  c.x=128;c.y=140;run(c,0xCC84,traps)
  assert c.memory[0x7e00]==0 and c.memory[0x651]&15==2,'native enemy damage consumes Mario fireball'
  assert c.memory[0x65]==8,'selected native weapon restored after added fireball damage';n+=1
  c=cpu();c.memory[0x21]=2
  for _ in range(3):run(c,h['SpawnFire'])
  assert c.memory[0x7e00]==1 and c.memory[0x7e10]==1,'two independent shots';n+=1
 else:
  for mode in ['descending','ascending','protected-pair']:
   c=cpu();set_values(c,{0x7d31:1,0x7d01:2,0x7d14:3,0x492:0x80,0x5c3:0x80})
   c.y=5
   if mode=='ascending':c.memory[0x7d14]=252
   if mode=='protected-pair':c.memory[0x7d14]=253;c.memory[0x7d19]=4
   run(c,h['StompBounce'],{0xCD00:lambda c:None})
   if mode!='ascending':
    assert c.memory[0x7d14]==253 and c.memory[0x5c3]&16,'native stomp flag and SMB bounce'
    assert c.memory[0x492]&32==0,'stomp must not hurt Mario'
   else:assert c.memory[0x5c3]&16==0,'ascending contact must not stomp'
   n+=1
  c=cpu();set_values(c,{0x7d65:0,0x7e00:1,0x7e01:128,0x7e02:164,0x5be:0x80,0x4a4:2,0x514:132,0x4f4:164,0x4f3:50,0x513:60})
  run(c,h['FireEnemy'])
  assert c.memory[0x5be]&32 and c.memory[0x7e00]==0,'fireball feeds native Diskarmor-hit processing'
  assert c.memory[0x4f3]==50 and c.memory[0x513]==60,'native Diskarmor position restored';n+=1
 report=dict(rom_sha256=m['output_sha256'],passed=True,cases=n,scope='Actual native damage/state handlers and patched gates under a 6502 CPU; native sound/score calls are isolated where noted.')
 (p/'build/combat-results.json').write_text(json.dumps(report,indent=2));print(f'PASS {game}: {n} native combat cases')
if __name__=='__main__':main(sys.argv[1])
