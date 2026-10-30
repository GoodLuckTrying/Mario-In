"""Execute Karnov/Rygar land adapters against verbatim assembled smb1base.

Flat-floor collision fixtures isolate the source motor. Native terrain,
equipment and camera integration are covered by the separate Mesen replays.
"""
from pathlib import Path
import importlib.util,json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from verify_physics import run,set_values

def main(game):
 p=ROOT/game;manifest=json.loads((p/'build/manifest.json').read_text());h=manifest['labels']
 spec=importlib.util.spec_from_file_location('contra_reference',ROOT/'contra/tools/audit_physics.py');ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
 ref.OUT=p/'build/physics-reference';ref.OUT.mkdir(exist_ok=True)
 code,v,s=ref.reference();rom=(p/'dist'/f'Mario in {game.capitalize()}.nes').read_bytes()
 state={}
 for line in (p/'src/state.inc').read_text().splitlines():
  if '='not in line:continue
  key,expr=line.split('=',1);state[key]=eval(expr.replace('$','0x'),{},state)
 fields={'Player_State':'M_STATE','Player_X_Speed':'M_SMB_X_SPEED','Player_X_MoveForce':'M_SMB_X_FORCE','Player_XSpeedAbsolute':'M_SMB_X_ABS','RunningSpeed':'M_RUNNING_SPEED','RunningTimer':'M_RUNNING_TIMER','PlayerFacingDir':'M_FACING','Player_MovingDir':'M_MOVING_DIR','Player_Y_Speed':'M_VY','Player_Y_MoveForce':'M_VY_FRAC','VerticalForce':'M_GRAVITY','VerticalForceDown':'M_FALL_FORCE'}
 cases=[];updates=0
 for direction in [1,2]:
  for scenario in ['walk','run','release','reverse','air-turn','jump-1','jump-2','jump-8','jump-25','down-direction','chain-jump']:
   for speed in ([0,8,9,15,16,24,25,27,28,32,33,40]if scenario.startswith('jump-')else[0]):
    smb=MPU();port=MPU();smb.memory[0x8000:]=code;port.memory[0x6000:0x7D00]=rom[16+(16*8192 if game=='karnov'else 8*16384):][:0x1D00]
    initial={'PlayerFacingDir':direction,'Player_MovingDir':direction,'AreaType':1,'GameEngineSubroutine':8,'PlayerSize':0,'Player_CollisionBits':3,'Player_X_Position':128,'Player_Y_Position':144,'Player_Y_HighPos':1,'VerticalForceDown':0x70,'Player_X_Speed':speed if direction==1 else -speed,'Player_XSpeedAbsolute':speed}
    set_values(smb,{v[k]:val for k,val in initial.items()})
    set_values(port,{state['M_MAGIC']:0x4D,state['M_FACING']:direction,state['M_MOVING_DIR']:direction,state['M_AREA_TYPE']:1,state['M_ENGINE_MODE']:8,state['M_FALL_FORCE']:0x70,state['M_SMB_X_SPEED']:speed if direction==1 else -speed,state['M_SMB_X_ABS']:speed})
    xp,yp,xf,yf=(0x63,0x64,state['M_X_FRAC'],state['M_Y_FRAC'])if game=='karnov'else(0x512,0x4F2,state['M_X_FRAC'],state['M_Y_FRAC'])
    port.memory[xp]=128;port.memory[yp]=144;port.memory[0x522]=0xA0
    def terrain(c):
     c.a=2 if c.y>=144 else 0;c.p=(c.p&~0x82)|(2 if c.a==0 else 0)
    failures=[]
    for tick in range(140):
     held=direction
     if scenario in ['run','release','reverse','air-turn','chain-jump']:held|=0x40
     if scenario=='release'and tick>=50:held=0
     if scenario=='reverse'and tick>=50:held=(direction^3)|0x40
     if scenario.startswith('jump-'):held=0x80 if tick<int(scenario.split('-')[1])else 0
     if scenario=='air-turn':
      if 30<=tick<55:held|=0x80
      if tick>=35:held=(direction^3)|(0x80 if tick<55 else 0)
     if scenario=='chain-jump'and 30<=tick%65<55:held|=0x80
     if scenario=='down-direction':held=direction|4
     for name in ['RunningTimer','JumpSwimTimer','ClimbSideTimer']:
      if smb.memory[v[name]]:smb.memory[v[name]]-=1
     smb.memory[v['SavedJoypadBits']]=held;smb.memory[v['Player_X_Position']]=128;port.memory[xp]=128
     if game=='karnov':port.memory[0x1B]=int(f'{held:08b}'[::-1],2)
     else:port.memory[0x28]=held
     run(smb,s['AuditStep'])
     run(port,h['Step'],{0xC3D8:terrain,0xC81D:lambda c:None}if game=='karnov'else{})
     if game=='rygar':
      for src,dst in [(5,yp),(7,xp)]:port.memory[dst]=port.memory[src]
     for cpu,source in [(smb,True),(port,False)]:
      y=cpu.memory[v['Player_Y_Position']]if source else cpu.memory[yp]
      vy=cpu.memory[v['Player_Y_Speed']]if source else cpu.memory[state['M_VY']]
      if y>=144 and vy<128:
       if source:
        for k in ['Player_State','Player_Y_Speed','Player_Y_MoveForce','Player_YMoveForceFractional']:cpu.memory[v[k]]=0
        cpu.memory[v['Player_Y_Position']]=144
       else:
        for k in ['M_STATE','M_VY','M_VY_FRAC']:cpu.memory[state[k]]=0
        cpu.memory[yf]=0;cpu.memory[yp]=144
     if game=='rygar':port.memory[0x522]=0xA0 if port.memory[yp]==144 else 0
     diff={k:[smb.memory[v[k]],port.memory[state[n]]]for k,n in fields.items()if smb.memory[v[k]]!=port.memory[state[n]]}
     for label,sa,pa in [('x',v['Player_X_Position'],xp),('y',v['Player_Y_Position'],yp),('xfrac',v['Position_X_Fraction'],xf),('yfrac',v['Player_YMoveForceFractional'],yf)]:
      if smb.memory[sa]!=port.memory[pa]:diff[label]=[smb.memory[sa],port.memory[pa]]
     if diff and not failures:failures.append(dict(tick=tick,held=held,differences=diff))
     smb.memory[v['PreviousA_B_Buttons']]=held&0xC0
     updates+=1
    cases.append(dict(direction=direction,scenario=scenario,initial_speed=speed,first_difference=failures[0]if failures else None))
 report=dict(rom_sha256=manifest['output_sha256'],reference_commit='46ff88f7d9e854db80bf8d50e5bf74340fcc64ce',cases=len(cases),updates=updates,matching_cases=sum(c['first_difference']is None for c in cases),results=cases)
 (p/'build/physics-results.json').write_text(json.dumps(report,indent=2))
 failures=[c for c in cases if c['first_difference']]
 assert not failures,failures[:6]
 print(f'PASS {game}: {len(cases)} SMB source cases, {updates} movement updates')
if __name__=='__main__':main(sys.argv[1])
