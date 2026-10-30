"""Native state, metatile, camera-unit and crowded-palette regressions."""
from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from verify_physics import run,set_values

def main(game):
 p=ROOT/game;m=json.loads((p/'build/manifest.json').read_text());h=m['labels'];rom=(p/'dist'/f'Mario in {game.capitalize()}.nes').read_bytes();cases=0
 state={}
 for line in(p/'src/state.inc').read_text().splitlines():
  if '='in line:
   k,e=line.split('=',1);state[k]=eval(e.replace('$','0x'),{},state)
 def cpu():
  c=MPU();start=16+(16*8192 if game=='karnov'else 8*16384);c.memory[0x6000:0x8000]=rom[start:start+8192];c.memory[0xc000:]=rom[16+15*16384:16+16*16384]
  at=0 if game=='karnov'else 5*16384;c.memory[0x8000:0xc000]=rom[16+at:16+at+16384]
  return c
 for x in [0,1,127,252,255]:
  for y in [0,1,127,237,239]:
   for dx in [-4,-1,0,1,4]:
    for dy in [-4,-1,0,1,4]:
     c=cpu();set_values(c,{state['M_LAST_SCROLL_X']:x,state['M_LAST_SCROLL_Y']:y,state['HOST_SCROLL_X']:(x+dx)%256,state['HOST_SCROLL_Y']:(y+dy)%240})
     run(c,h['UpdateCamera'])
     assert c.memory[state['M_CAM_DELTA_X']]==dx%256 and c.memory[state['M_CAM_DELTA_Y']]==dy%256,'integer camera units and native 240-line wrap'
     cases+=1
 if game=='karnov':
  base=Path(m['base_rom']).read_bytes()[16:]
  for raw in [0,1,2,3,4,5,8,9,10,11,12,16,31,128,133,150,200,255]:
   c=cpu();c.memory[0x40c:0x4cc]=[raw]*192;c.x=64;c.y=144
   expected=0 if 16<=raw<128 else raw
   if raw>=128:expected=base[0x1ac8+base[0x1bca+(raw&127)*3]]>>2
   run(c,h['Point']);assert c.a==expected and bool(c.p&2)==(expected==0),'native metatile class and zero flag';cases+=1
  for action in [10,11,14,15,16,19,22,25,26,28]:
   c=cpu();set_values(c,{0x7d00:0x4d,0x7d01:1,0x7d31:1,0x62:action,0x63:80,0x64:100,0x65:0x13});seen=[]
   run(c,h['PlayerGate'],{0xf29b:lambda c:seen.append(c.a)})
   assert seen==[action]and c.memory[0x7d31]==0 and c.memory[0x63:0x66]==[80,100,0x13],'native ladder/flight/hurt/script handoff';cases+=1
  c=cpu();set_values(c,{0x7d00:0x4d,0x7d35:1,0x10:11,0x68:0x40,0x34:0x10,0x35:0x1c,0x36:0x0f,0x38:0x28,0x39:0x16,0x3a:0x0f})
  for a in range(0x200,0x300,4):c.memory[a]=240
  for a,palette in [(0x200,0),(0x258,0),(0x25c,1),(0x260,2),(0x264,3)]:set_values(c,{a:16,a+2:palette})
  for a in range(0x214,0x224,4):set_values(c,{a:100,a+1:0x21,a+2:0})
  run(c,h['PrepareWait'],{0xc063:lambda c:None})
  assert c.memory[0x7d4d]<4,'crowded injury frame must still provide Fire Mario colors'
  assert [c.memory[a+2]for a in [0x25c,0x260,0x264]]==[1,2,3],'native enemy palettes stay intact';cases+=1
 else:
  for action in [0x20,0x30,0x38,0x40,0x60,0x70]:
   c=cpu();set_values(c,{0x7d00:0x4d,0x7d5a:14,0x1c:14,0x7d01:1,0x7d31:1,0x4b2:action,0x492:0x80,0x4f2:100,0x512:80,0x4c2:32,0x4d2:224})
   ref=MPU(memory=c.memory.copy());ref.x=0;ref.p&=254;run(ref,0x962b);run(c,h['BeginStep'])
   assert c.memory[4:8]==ref.memory[4:8]and c.memory[0x4c2:0x4d3]==ref.memory[0x4c2:0x4d3]and c.memory[0x7d31]==0,'native tool/script motion retained';cases+=1
 report=dict(rom_sha256=m['output_sha256'],passed=True,cases=cases)
 (p/'build/state-results.json').write_text(json.dumps(report,indent=2));print(f'PASS {game}: {cases} native state/collision/camera cases')
if __name__=='__main__':main(sys.argv[1])
