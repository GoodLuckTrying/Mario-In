"""Compare both controllers' land movement to the original SMB1 instructions."""
from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'tools'))
from verify_physics import run,set_values

def main():
    manifest=json.loads((ROOT/'build/manifest.json').read_text());H=manifest['labels'];N=manifest['native']
    ref=json.loads((ROOT.parent/'kidicarus/tests/smb-reference-symbols.json').read_text())['labels']
    original=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[16:0x8010]
    rom=(ROOT/'dist/Mario and Luigi in Contra.nes').read_bytes()
    failures=[];cases=0;updates=0
    for player in [0,1]:
      b=0x6000+128*player
      for kind in ['walk','run','release','reverse','air-neutral','air-turn','jump-short','jump-full','duck-jump']:
       for direction in [-1,1]:
        for power in range(3):
         cases+=1;smb=MPU();port=MPU();smb.memory[0x8000:]=original
         port.memory[0x8000:0xC000]=rom[16+8*16384:16+9*16384];port.memory[0xC000:]=rom[16+15*16384:]
         d=1 if direction>0 else 2
         set_values(smb,{0x33:d,0x45:d,0x74e:1,0xe:8,0x754:int(power==0),0x490:3,0x86:64,0xce:144,0x70a:0x70})
         set_values(port,{b:0x4D,b+4:power,b+0xB:d,b+0xC:d,b+0x14:1,b+0x15:8,b+0x1B:0x70,b+0x20:0xFF,b+0x37:0,
                          N['SPRITE_X_POS']+player:64,N['SPRITE_Y_POS']+player:164,N['PLAYER_STATE']+player:1,0x6101:player})
         def terrain(c):
            # Down+A now deliberately drops through one-way platforms;
            # retain the SMB crouch-jump comparison on a solid floor.
            c.a=(0x80 if kind=='duck-jump' else 1) if c.y>=176 else 0
            c.p=(c.p&~0x83)|(c.a&0x80)|(1 if c.a==1 else 2 if c.a==0 else 0)
         def move_x(c):
            a=N['SPRITE_X_POS']+player
            c.memory[a]=(c.memory[a]+c.memory[N['PLAYER_X_VELOCITY']+player])&255
         def mario_terrain(c):
            c.y=c.a
            terrain(c)
         traps={N['get_bg_collision']:terrain,H['P'+str(player)+'Tile']:mario_terrain,N['calc_player_x_vel']:move_x}
         for tick in range(80):
            # Keep this CPU comparison away from Contra's screen edges;
            # compare the exact per-tick displacement and all SMB state.
            set_values(smb,{0x86:128});set_values(port,{N['SPRITE_X_POS']+player:128})
            held=d
            if kind in ['run','release','reverse','air-neutral','air-turn','duck-jump']:held|=0x40
            if kind=='release' and tick>=35:held=0
            if kind=='reverse' and tick>=35:held=(d^3)|0x40
            if kind.startswith('jump-'):held=0x80 if tick<(1 if kind=='jump-short' else 25) else 0
            if kind=='air-neutral' and tick>=10:held=0x80 if tick<35 else 0
            if kind=='air-turn' and tick>=10:held=0x80|(d^3)
            if kind=='duck-jump':held=0x84 if tick<25 else 0
            set_values(smb,{0xA:held&0xC0,0xB:held&0xC,0xC:held&3,0x6FC:held})
            if smb.memory[0x783]:smb.memory[0x783]-=1
            if smb.memory[0x782]:smb.memory[0x782]-=1
            if smb.memory[0x789]:smb.memory[0x789]-=1
            set_values(port,{N['CONTROLLER_STATE']+player:held})
            run(smb,ref['PlayerMovementSubs']);run(port,H['P'+str(player)+'Move'],traps)
            if smb.memory[0xCE]>=144 and smb.memory[0x9F]<128:set_values(smb,{0xCE:144,0x1D:0,0x9F:0,0x433:0,0x416:0})
            if smb.memory[0x57]:smb.memory[0x45]=2 if smb.memory[0x57]>=128 else 1
            pairs={'vx':(0x57,6),'xforce':(0x705,7),'abs':(0x700,8),'xfrac':(0x400,0x16),
                   'vy':(0x9F,0x18),'vyfrac':(0x433,0x19),'yfrac':(0x416,0x17),'state':(0x1D,5),
                   'facing':(0x33,0xB),'run':(0x703,9),'timer':(0x783,0xA),'fall':(0x70A,0x1B),'gravity':(0x709,0x1A)}
            diff={k:[smb.memory[a],port.memory[b+o]] for k,(a,o) in pairs.items() if smb.memory[a]!=port.memory[b+o]}
            if (smb.memory[0xCE]+20)&255!=port.memory[N['SPRITE_Y_POS']+player]:diff['y']=[smb.memory[0xCE]+20,port.memory[N['SPRITE_Y_POS']+player]]
            if smb.memory[0x86]!=port.memory[N['SPRITE_X_POS']+player]:diff['x']=[smb.memory[0x86],port.memory[N['SPRITE_X_POS']+player]]
            if diff:failures.append({'case':[player,kind,direction,power],'tick':tick,'differences':diff});break
            smb.memory[0xD]=held&0xC0;updates+=1
    report={'cases':cases,'matched_updates':updates,'failures':failures}
    (ROOT/'build/physics-results.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2)[:6500]);assert not failures,'SMB movement comparison failed'
if __name__=='__main__':main()
