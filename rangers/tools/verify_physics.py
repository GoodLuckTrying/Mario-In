from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT.parent/'tools'))
from verify_physics import run,set_values
def main():
 h=json.loads((ROOT/'build/manifest.json').read_text())['labels']
 ref=json.loads((ROOT.parent/'tests/smb-reference-symbols.json').read_text())['labels']
 original=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[16:0x8010]
 rom=(ROOT/'dist/Mario and Luigi in Rescue Rangers.nes').read_bytes()
 failures=[];updates=0;cases=0
 for player in range(2):
  for kind in ['walk','run','release','reverse','air-neutral','air-turn','jump-short','jump-full','duck-jump']:
   for direction in [-1,1]:
    for power in range(3):
     cases+=1;smb=MPU();port=MPU();smb.memory[0x8000:]=original
     port.memory[0x6A00:0x8000]=rom[16+8*16384:16+8*16384+0x1600]
     d=1 if direction>0 else 2
     set_values(smb,{0x33:d,0x45:d,0x74e:1,0xe:8,0x754:int(power==0),0x490:3,0x86:96,0xce:144,0x70a:0x70})
     set_values(port,{0x6980:player,0x6900:0x4D,0x6904:power,0x690B:d,0x690C:d,0x6914:1,0x6915:8,0x691B:0x70,
                      0x4F0+player:96,0x510+player:164,0x6920:255,0x6937:0})
     def terrain(c):
      a=3 if c.memory[0x6985]>=176 else 0
      c.a=a;c.p=(c.p&~0x83)|(2 if a==0 else 0)
     traps={h['Tile']:terrain,0xD3E7:lambda c:None,0xD40B:lambda c:None,0xF217:lambda c:None,0xF379:lambda c:None}
     def clear_c(c):c.p&=~1
     traps.update({a:clear_c for a in [0xF5A6,0xF721,0xF62D]})
     # The common interpreter's trap RTS scratch must not overwrite live code.
     def call(c,addr):
      c.sp=0xFD;c.memory[0x1FE]=0xFE;c.memory[0x1FF]=0x5F;c.memory[0x5FFE]=0x60;c.pc=addr
      for n in range(30000):
       if c.pc==0x5FFF:return
       if c.pc in traps:
        traps[c.pc](c);c.pc=0x5FFE
       c.step()
      raise AssertionError(hex(c.pc))
     for tick in range(80):
      held=d
      if kind in ['run','release','reverse','air-neutral','air-turn','duck-jump']:held|=64
      if kind=='release' and tick>=35:held=0
      if kind=='reverse' and tick>=35:held=(d^3)|64
      if kind.startswith('jump-'):held=128 if tick<(1 if kind=='jump-short' else 25) else 0
      if kind=='air-neutral' and tick>=10:held=128 if tick<35 else 0
      if kind=='air-turn' and tick>=10:held=128|(d^3)
      if kind=='duck-jump':held=132 if tick<25 else 0
      set_values(smb,{0xA:held&192,0xB:held&12,0xC:held&3,0x6FC:held})
      for a in [0x783,0x782,0x789]:
       if smb.memory[a]:smb.memory[a]-=1
      set_values(port,{0x16+player:held,0x14+player:0})
      run(smb,ref['PlayerMovementSubs']);call(port,h['Move'])
      if smb.memory[0xCE]>=144 and smb.memory[0x9F]<128:set_values(smb,{0xCE:144,0x1D:0,0x9F:0,0x433:0,0x416:0})
      if smb.memory[0x57]:smb.memory[0x45]=2 if smb.memory[0x57]>=128 else 1
      pairs={'vx':(0x57,6),'xforce':(0x705,7),'abs':(0x700,8),'xfrac':(0x400,0x16),'vy':(0x9F,0x18),
       'vyfrac':(0x433,0x19),'yfrac':(0x416,0x17),'state':(0x1D,5),'facing':(0x33,11),'run':(0x703,9),
       'timer':(0x783,10),'fall':(0x70A,0x1B),'gravity':(0x709,0x1A)}
      diff={k:[smb.memory[a],port.memory[0x6900+o]] for k,(a,o) in pairs.items() if smb.memory[a]!=port.memory[0x6900+o]}
      if (smb.memory[0xCE]+20)&255!=port.memory[0x510+player]:diff['y']=[smb.memory[0xCE]+20,port.memory[0x510+player]]
      if smb.memory[0x86]!=port.memory[0x4F0+player]:diff['x']=[smb.memory[0x86],port.memory[0x4F0+player]]
      if diff:failures.append({'case':[player,kind,direction,power],'tick':tick,'diff':diff});break
      smb.memory[0xD]=held&192;updates+=1
 report={'cases':cases,'matched_updates':updates,'failures':failures}
 (ROOT/'build/physics-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report)[:6500]);assert not failures
if __name__=='__main__':main()
