from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'tools'))
from verify_physics import run
j=json.loads((ROOT/'build/manifest.json').read_text());H=j['labels'];N=j['native']
rom=(ROOT/'dist/Mario and Luigi in Contra.nes').read_bytes();cases=0
# Actual native enemy-box calculation, followed by the assembled Mario
# expansion. A small crouch must lower the exposed head by four pixels;
# directions/airborne states must restore its normal standing envelope.
for player in range(2):
 for power in range(3):
  for state in [0,1,2]:
   for buttons in [0,4,5,6,0x44,0x84]:
    for duck in [0,1]:
     c=MPU();m=c.memory
     m[0x8000:0xc000]=rom[16+8*16384:16+9*16384];m[0xc000:]=rom[16+15*16384:]
     b=0x6000+player*128;c.x=player
     m[b+4]=power;m[b+0x1d]=duck
     m[N['CONTROLLER_STATE']+player]=buttons;m[N['PLAYER_JUMP_STATUS']+player]=state
     m[N['ENEMY_CURRENT_SLOT']]=15;m[N['ENEMY_STATE_WIDTH']+15]=0
     m[N['ENEMY_X_POS']+15]=100;m[N['ENEMY_Y_POS']+15]=100
     c.y=4;run(c,N['set_enemy_collision_box']);original=m[8:12]
     c.x=player;run(c,H['PlayerBoxGate'])
     height=28 if power and not duck else 8 if power==0 and state==0 and buttons&15==4 else 12
     assert m[8]==(original[0]-10)&255 and m[9]==(original[1]-5)&255
     assert m[10]==original[2]+height and m[11]==original[3]+10,(player,power,state,buttons,duck,m[10],height)
     cases+=1
print('PASS',cases,'native collision envelopes: small crouch head clearance, full airborne/diagonal height, tall/crouched forms, both players')
