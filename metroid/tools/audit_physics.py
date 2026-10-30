"""Compare the complete normal-form Mario motion with assembled SMB1 code.

Native doors, water/lava, knockback, Small Mario/Morph Ball and High Jump Boots
are intentional host adaptations and have separate emulator fixtures.
"""
from pathlib import Path
import importlib.util,json,sys,hashlib
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'metroid'
spec=importlib.util.spec_from_file_location('source',ROOT/'contra/tools/audit_physics.py')
source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
sys.path.insert(0,str(ROOT/'tools'))
from audit_all_physics import execute

def main():
 source.OUT=P/'build/physics-audit';source.OUT.mkdir(exist_ok=True)
 code,V,S=source.reference();meta=json.loads((P/'build/manifest.json').read_text());H=meta['labels'];N=meta['native']
 rom=(P/'dist/Mario in Metroid.nes').read_bytes();results=[];b=0x6c74
 for direction in (1,2):
  for scenario in ('walk','run','release','reverse','jump-1','jump-2','jump-8','jump-25','air-turn','chain','down-direction','walk-off'):
   for speed in ([0,8,9,15,16,24,25,27,28,32,33,40] if scenario.startswith('jump') else [0]):
    smb=MPU();port=MPU();smb.memory[0x8000:]=code
    port.memory[0x7400:0x77f0]=(P/'build/code-a.bin').read_bytes()
    # Assign ranges separately: the gap at $7800 contains native Metroid state.
    port.memory[0x7900:0x8000]=(P/'build/code-b.bin').read_bytes();port.memory[0x8000:0xc000]=rom[16+16384:16+2*16384];port.memory[0xc000:]=rom[16+15*16384:]
    m=port.memory;execute(port,H['Init'])
    values={'PlayerFacingDir':direction,'Player_MovingDir':direction,'AreaType':1,'GameEngineSubroutine':8,'PlayerSize':0,'Player_CollisionBits':3,
      'Player_X_Position':128,'Player_Y_Position':144,'Player_Y_HighPos':1,'VerticalForceDown':0x70,'Player_X_Speed':speed if direction==1 else -speed,'Player_XSpeedAbsolute':speed}
    for key,val in values.items():smb.memory[V[key]]=val&255
    for addr,val in {0x300:0,0x30e:128,0x30d:161,0x301:15,b+2:speed if direction==1 else -speed,b+4:speed,b+7:direction,b+8:direction}.items():m[addr]=val&255
    floor=True
    def support(c):c.p=(c.p&~1)|(0 if floor and m[0x30d]>=161 else 1)
    traps={H['Support']:support}
    pairs={'Player_X_Speed':b+2,'Player_X_MoveForce':b+3,'Player_XSpeedAbsolute':b+4,'RunningSpeed':b+5,
      'RunningTimer':b+6,'PlayerFacingDir':b+7,'Player_MovingDir':b+8,'Position_X_Fraction':b+36,'Player_YMoveForceFractional':b+37,
      'Player_Y_Speed':b+20,'Player_Y_MoveForce':b+21,'Player_State':b+1,'VerticalForce':b+22,'VerticalForceDown':b+23}
    first=None;rise=[0,0];prev=0
    for tick in range(140):
     held=direction
     if scenario in ('run','release','reverse','air-turn','chain'):held|=64
     if scenario=='release' and tick>=50:held=0
     if scenario=='reverse' and tick>=50:held=(direction^3)|64
     if scenario.startswith('jump-'):held=128 if tick<int(scenario.split('-')[1]) else 0
     if scenario=='air-turn' and tick>=30:held=(direction^3)|(128 if tick<55 else 0)
     if scenario=='chain' and 30<=tick%65<55:held|=128
     if scenario=='down-direction':held=direction|4
     if scenario=='walk-off' and tick>=30:floor=False
     for name in ('RunningTimer','JumpSwimTimer','ClimbSideTimer'):
      if smb.memory[V[name]]:smb.memory[V[name]]-=1
     smb.memory[V['SavedJoypadBits']]=held;smb.memory[V['Player_X_Position']]=128;m[0x30e]=128;m[0x14]=held;m[0x12]=held&~prev
     if not floor and smb.memory[V['Player_State']]==0:smb.memory[V['Player_State']]=2
     execute(smb,S['AuditStep']);execute(port,H['Step'],traps)
     execute(port,H['Horizontal']);dx=m[0] if m[0]<128 else m[0]-256;m[0x30e]=(m[0x30e]+dx)&255
     execute(port,H['Vertical']);dy=m[0] if m[0]<128 else m[0]-256;m[0x30d]=(m[0x30d]+dy)&255
     if floor and m[0x30d]>=161 and dy>=0:
      m[0x30d]=161;execute(port,H['Land']);m[0x314]=0
     if floor and smb.memory[V['Player_Y_Position']]>=144 and smb.memory[V['Player_Y_Speed']]<128:
      for key in ('Player_State','Player_Y_Speed','Player_Y_MoveForce','Player_YMoveForceFractional'):smb.memory[V[key]]=0
      smb.memory[V['Player_Y_Position']]=144
     diffs={key:[smb.memory[V[key]],m[addr]] for key,addr in pairs.items() if smb.memory[V[key]]!=m[addr]}
     if ((smb.memory[V['Player_Y_Position']]+17)&255)!=m[0x30d]:diffs['y']=[(smb.memory[V['Player_Y_Position']]+17)&255,m[0x30d]]
     if smb.memory[V['Player_X_Position']]!=m[0x30e]:diffs['x']=[smb.memory[V['Player_X_Position']],m[0x30e]]
     if diffs and first is None:first=dict(tick=tick,held=held,differences=diffs)
     rise[0]=max(rise[0],144-smb.memory[V['Player_Y_Position']]);rise[1]=max(rise[1],161-m[0x30d])
     smb.memory[V['PreviousA_B_Buttons']]=held&0xC0;prev=held
    results.append(dict(direction=direction,scenario=scenario,speed=speed,rise=rise,first_difference=first))
 report=dict(candidate_sha256=hashlib.sha256(rom).hexdigest(),cases=len(results),updates=len(results)*140,matching=sum(r['first_difference'] is None for r in results),results=results)
 (P/'build/physics-audit/results.json').write_text(json.dumps(report,indent=2))
 print('Physics:',report['matching'],'/',report['cases'])
 for r in results:
  if r['first_difference']:print(r);break
 assert report['matching']==report['cases']
if __name__=='__main__':main()
