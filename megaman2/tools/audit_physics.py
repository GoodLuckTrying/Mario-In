"""Execute the complete Mario controller against the assembled SMB1 source."""
from pathlib import Path
import importlib.util,json,sys,hashlib
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'megaman2'
spec=importlib.util.spec_from_file_location('source',ROOT/'contra/tools/audit_physics.py')
source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
sys.path.insert(0,str(ROOT/'tools'))
from audit_all_physics import execute

def main():
 source.OUT=P/'build/physics-audit';source.OUT.mkdir(exist_ok=True)
 code,V,S=source.reference();meta=json.loads((P/'build/manifest.json').read_text());H=meta['labels'];N=meta['native']
 binary=(P/'build/code.bin').read_bytes();rom=(P/'dist/Mario in Mega Man 2.nes').read_bytes()
 results=[]
 for direction in (1,2):
  for scenario in ('walk','run','release','reverse','jump-1','jump-2','jump-8','jump-25','air-turn','chain','down-direction','walk-off'):
   for speed in ([0,8,9,15,16,24,25,27,28,32,33,40] if scenario.startswith('jump') else [0]):
    smb=MPU();port=MPU();smb.memory[0x8000:]=code;port.memory[0x6000:0x6000+len(binary)]=binary
    port.memory[0x8000:0xC000]=rom[16+14*16384:16+15*16384];port.memory[0xC000:]=rom[16+15*16384:]
    m=port.memory
    execute(port,H['Init'])
    values={'PlayerFacingDir':direction,'Player_MovingDir':direction,'AreaType':1,'GameEngineSubroutine':8,'PlayerSize':0,'Player_CollisionBits':3,
      'Player_X_Position':128,'Player_Y_Position':144,'Player_Y_HighPos':1,'VerticalForceDown':0x70,'Player_X_Speed':speed if direction==1 else -speed,'Player_XSpeedAbsolute':speed}
    for key,val in values.items():smb.memory[V[key]]=val&255
    for addr,val in {0x2C:6,0x460:128,0x4A0:164,H['M_SMB_X_SPEED']:speed if direction==1 else -speed,0x7004:speed,0x7007:direction,0x7008:direction}.items():m[addr]=val&255
    floor=True
    def blank(c):pass
    def platform(c):c.p&=~1
    def tile(c):m[0]=int(floor and m[0x0A]>=176)
    def horizontal(c):
     pos=(m[0x460]<<8)|m[0x480];vel=(m[0x600]<<8)|m[0x620]
     pos=(pos+vel if m[0x42]&64 else pos-vel)&65535;m[0x460]=pos>>8;m[0x480]=pos&255
    def vertical(c):
     pos=((m[0x4A0]<<8)|m[0x4C0])-((m[0x640]<<8)|m[0x660]);pos&=65535
     if floor and m[0x640]>=128 and pos>>8>=164:
      pos=164<<8;m[0x640]=m[0x660]=0
     m[0x4A0]=pos>>8;m[0x4C0]=pos&255
    traps={N['player_check_fire_weapon']:blank,N['check_platform_collision']:platform,N['player_floor_tile_check']:tile,N['player_horiz_movement']:horizontal,N['player_vertical_physics']:vertical,N['player_set_sprite']:blank,N['sound_queue_push']:blank}
    first=None;rise=[0,0]
    pairs={'Player_X_Speed':H['M_SMB_X_SPEED'],'Player_X_MoveForce':H['M_SMB_X_FORCE'],'Player_XSpeedAbsolute':0x7004,'RunningSpeed':0x7005,
      'RunningTimer':0x7006,'PlayerFacingDir':0x7007,'Player_MovingDir':0x7008,'Position_X_Fraction':0x480,'Player_YMoveForceFractional':0x4C0,
      'Player_Y_Speed':H['M_VY'],'Player_Y_MoveForce':H['M_VY_FRAC'],'Player_State':H['M_STATE'],'VerticalForce':0x7016,'VerticalForceDown':0x7017}
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
     smb.memory[V['SavedJoypadBits']]=held;smb.memory[V['Player_X_Position']]=128;m[0x460]=128
     m[0x23]=int(f'{held:08b}'[::-1],2)
     if not floor and smb.memory[V['Player_State']]==0:smb.memory[V['Player_State']]=2
     execute(smb,S['AuditStep']);execute(port,H['Motion'],traps)
     if floor and smb.memory[V['Player_Y_Position']]>=144 and smb.memory[V['Player_Y_Speed']]<128:
      for key in ('Player_State','Player_Y_Speed','Player_Y_MoveForce','Player_YMoveForceFractional'):smb.memory[V[key]]=0
      smb.memory[V['Player_Y_Position']]=144
     diffs={key:[smb.memory[V[key]],m[addr]] for key,addr in pairs.items() if smb.memory[V[key]]!=m[addr]}
     if ((smb.memory[V['Player_Y_Position']]+20)&255)!=m[0x4A0]:diffs['y']=[(smb.memory[V['Player_Y_Position']]+20)&255,m[0x4A0]]
     if smb.memory[V['Player_X_Position']]!=m[0x460]:diffs['x']=[smb.memory[V['Player_X_Position']],m[0x460]]
     if diffs and first is None:first=dict(tick=tick,held=held,differences=diffs)
     rise[0]=max(rise[0],144-smb.memory[V['Player_Y_Position']]);rise[1]=max(rise[1],164-m[0x4A0])
     smb.memory[V['PreviousA_B_Buttons']]=held&0xC0
    results.append(dict(direction=direction,scenario=scenario,speed=speed,rise=rise,first_difference=first))
 report=dict(candidate_sha256=hashlib.sha256(rom).hexdigest(),cases=len(results),updates=len(results)*140,matching=sum(r['first_difference'] is None for r in results),results=results)
 (P/'build/physics-audit/results.json').write_text(json.dumps(report,indent=2))
 print('Physics:',report['matching'],'/',report['cases'])
 for r in results:
  if r['first_difference']:print(r);break
 assert report['matching']==report['cases']
if __name__=='__main__':main()
