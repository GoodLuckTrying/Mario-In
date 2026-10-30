"""Source-based movement audit. Never rebuilds or installs a game ROM."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import sys
from py65.devices.mpu6502 import MPU

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/physics-audit'
CANDIDATE=False
spec=importlib.util.spec_from_file_location('contra_source_audit',ROOT/'contra/tools/audit_physics.py')
source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
NAMES={'kidicarus':'Mario in Kid Icarus','contra':'Mario and Luigi in Contra',
       'rangers':'Mario and Luigi in Rescue Rangers','kungfu':'Mario in Kung Fu',
       'tetris':'Mario in Tetris','smb2':'SMB1 Mario and Luigi in Super Mario Bros 2',
       'gradius':'Mario in Gradius','snake':'Mario and Luigi in Snake Rattle n Roll',
       'zelda':'Mario in The Legend of Zelda','wwf':'Mario and Luigi in WWF WrestleMania'}


def execute(c,pc,traps=None):
    # The original shared run() uses $6F00 for trap RTS. Several ports execute
    # their controller there, so use otherwise unused $5FFE instead.
    c.sp=0xfd;c.memory[0x1fe:0x200]=[0xfe,0x5f];c.memory[0x5ffe]=0x60;c.pc=pc
    for _ in range(40000):
        if c.pc==0x5fff:return
        if traps and c.pc in traps:
            traps[c.pc](c);c.pc=0x5ffe
        c.step()
    raise AssertionError(f'Call did not return: {pc:04X} -> {c.pc:04X}')


class Port:
    def __init__(self,game,p,power,direction,speed):
        self.game=game;self.root=ROOT/game
        self.meta=json.loads((self.root/'build/manifest.json').read_text());self.H=self.meta['labels'];self.N=self.meta.get('native',{})
        rom_path=(self.root/'dist'/(NAMES[game]+'.nes'))if CANDIDATE else Path('C:/nes',NAMES[game]+'.nes')
        self.rom=rom_path.read_bytes();self.c=MPU();self.m=self.c.memory
        self.p=p;self.power=power;self.floor=True;self.traps={}
        self.hold=0;self.first=True
        self.mapping={'Player_X_Speed':6,'Player_X_MoveForce':7,'Player_XSpeedAbsolute':8,'RunningSpeed':9,
                      'RunningTimer':10,'PlayerFacingDir':11,'Player_MovingDir':12,'Position_X_Fraction':22,
                      'Player_YMoveForceFractional':23,'Player_Y_Speed':24,'Player_Y_MoveForce':25,
                      'VerticalForce':26,'VerticalForceDown':27,'Player_State':5}
        def store(values):
            for a,v in values.items():self.m[a]=v&255
        self.store=store
        if game=='kidicarus':
            self.b=0x6800;self.x=0x723;self.y=0x720;self.y0=168;self.shift=24;self.entry=self.H['MarioUpdate']
            self.m[0x8000:0xc000]=(self.root/'build/bank8.bin').read_bytes()
            self.m[0xc000:]=Path('C:/nes/Kid Icarus (USA, Europe).nes').read_bytes()[16+7*16384:]
            load=self.H['__BRIDGES_LOAD__']-0x8000
            self.m[0x6100:0x6800]=self.m[0x8000+load:0x8000+load+0x700]
            store({0x6800:0x4d,0x6801:2,0xa0:2,0x6837:2,0x6820:255,0x6814:1,0x6815:8})
            self.traps[self.H['NativeTerrainEffect']]=lambda c:None
            def tile(c):
                c.a=0x40 if self.floor and c.a>=176 else 0
                c.memory[0x6823]=c.a;c.y=0;c.p=(c.p&~0x83)|(2 if c.a==0 else 0)
            self.traps[self.H['TileAt']]=tile
        elif game=='rangers':
            self.b=0x6900;self.x=0x4f0+p;self.y=0x510+p;self.y0=164;self.shift=20;self.entry=self.H['Move']
            self.m[0x6a00:0x8000]=self.rom[16+8*16384:16+8*16384+0x1600]
            store({0x6980:p,self.b:0x4d,self.b+0x14:1,self.b+0x15:8,self.b+0x20:255})
            def tile(c):
                c.a=3 if self.floor and c.memory[0x6985]>=176 else 0
                c.p=(c.p&~0x83)|(2 if c.a==0 else 0)
            self.traps[self.H['Tile']]=tile
            for a in [0xd3e7,0xd40b,0xf217,0xf379]:self.traps[a]=lambda c:None
            for a in [0xf5a6,0xf721,0xf62d]:self.traps[a]=lambda c:setattr(c,'p',c.p&~1)
        elif game=='tetris':
            self.b=0x7800;self.x=0x7801;self.y=0x7802;self.y0=208;self.shift=64;self.entry=self.H['Step']
            self.m[0x8000:]=self.rom[16:0x8010]
            self.m[0x6000:0x7800]=(self.root/'build/hack.bin').read_bytes()[:0x1800]
            self.m[0x400:0x4c8]=[0xef]*200
            execute(self.c,self.H['Init'])
            self.mapping={'Player_X_Speed':0x21,'Player_X_MoveForce':0x22,'Player_XSpeedAbsolute':0x23,
                          'RunningSpeed':0x24,'RunningTimer':0x25,'PlayerFacingDir':0x26,'Player_MovingDir':0x27,
                          'Position_X_Fraction':3,'Player_YMoveForceFractional':4,'Player_Y_Speed':5,
                          'Player_Y_MoveForce':6,'VerticalForce':7,'VerticalForceDown':8,'Player_State':0x20}
            def tile(c):
                c.a=int(self.floor and c.a>=208);c.p=(c.p&~0x83)|(2 if c.a==0 else 0)
            self.traps[self.H['Tile']]=tile
            # The active piece is absent in the empty flat-floor fixture.
            listing=(self.root/'build/mario.lst').read_text()
            for name in ['ActiveBody']:
                matches=re.findall(r'^([0-9A-Fa-f]{6})r?\s+\d+\s+'+name+':',listing,re.M)
                if matches:self.traps[0x6000+int(matches[0],16)]=lambda c:(setattr(c,'a',0),setattr(c,'p',(c.p&~0x83)|2))
        elif game=='kungfu':
            self.b=0x7d00;self.x=0xd4;self.y=0x7c04;self.y0=135;self.shift=-9;self.entry=self.H['Step']
            self.m[0x8000:]=self.rom[16:0x8010]
            data=(self.root/'build/hack.bin').read_bytes();self.m[0x6000:0x6000+len(data)]=data
            self.m[0x7c00:0x8000]=[0]*1024
            store({0x51:2,0x4a6:48,0x7c04:135,0xb6:135,0xd4:128,0xe5:6,0x65:6,0x94:120,0x7c00:power})
            self.mapping={'Player_X_Speed':1,'Player_X_MoveForce':2,'Player_XSpeedAbsolute':3,'RunningSpeed':4,
                          'RunningTimer':5,'PlayerFacingDir':6,'Player_MovingDir':7,'Position_X_Fraction':18,
                          'Player_YMoveForceFractional':0x7c07-self.b,'Player_Y_Speed':0x7c05-self.b,
                          'Player_Y_MoveForce':0x7c06-self.b,'Player_State':0x7c08-self.b}
            # Isolate Mario's pixel delta from Thomas's camera/boss machinery.
            def native_pixel(c):
                self.m[self.x]=(self.m[self.x]+(1 if self.m[0x67]==1 else -1))&255
            self.traps[0xa797]=native_pixel
            for a in [0xa6f6,0xa734]:self.traps[a]=lambda c:None
        elif game=='smb2':
            self.b=0x7e00;self.x=self.H['PlayerXLo'];self.y=self.H['PlayerYLo'];self.y0=144;self.shift=0
            self.m[0xc000:]=self.rom[16+7*0x4000:16+8*0x4000]
            self.mapping={'Player_X_Speed':self.H['PlayerXVelocity']-self.b,'Player_X_MoveForce':1,
                          'Player_XSpeedAbsolute':2,'RunningSpeed':3,'RunningTimer':4,
                          'Position_X_Fraction':self.H['PlayerXSubpixel']-self.b}
            if 'MarioApplyY'in self.H:
                self.mapping.update({'Player_YMoveForceFractional':self.H['PlayerYSubpixel']-self.b,
                                     'Player_Y_Speed':0x11,'Player_Y_MoveForce':0x12,
                                     'VerticalForce':0x13,'VerticalForceDown':0x20})
            store({self.H['CurrentCharacter']:p,self.H['PlayerCurrentSize']:int(power==0),
                   self.H['PlayerDirection']:int(direction==1),self.H['PlayerMovementDirection']:direction,
                   self.H['IsHorizontalLevel']:1,0x7e13:0x70,0x7e20:0x70})
        else:raise ValueError(game)
        if game in ['kidicarus','rangers']:
            store({self.b+4:power,self.b+11:direction,self.b+12:direction,self.b+0x1b:0x70,self.b+6:speed if direction==1 else -speed,self.b+8:speed})
        else:
            if 'PlayerFacingDir'in self.mapping:store({self.b+self.mapping['PlayerFacingDir']:direction,self.b+self.mapping['Player_MovingDir']:direction})
            store({self.b+self.mapping['Player_X_Speed']:speed if direction==1 else -speed,self.b+self.mapping['Player_XSpeedAbsolute']:speed})
        store({self.x:128,self.y:self.y0})

    def step(self,held,tick):
        self.m[self.x]=128
        if self.game=='kidicarus':self.m[0x16]=held
        if self.game=='rangers':self.m[0x16+self.p]=held;self.m[0x14+self.p]=0
        if self.game=='tetris':self.m[self.N['heldButtons_player1']]=held
        if self.game=='kungfu':self.m[0x6a]=(held&~0x80)|(8 if held&0x80 else 0)
        if self.game=='smb2':
            H=self.H
            self.m[H['Player1JoypadHeld']]=held;self.m[H['Player1JoypadPress']]=held&~self.hold
            self.hold=held
            if not self.floor and self.m[H['PlayerInAir']]==0:self.m[H['PlayerInAir']]=1
            self.m[0x8000:0xc000]=self.rom[16+3*0x4000:16+4*0x4000]
            execute(self.c,H['MarioGravity']);execute(self.c,H['MarioControl'])
            if 'MarioApplyY'in H:
                execute(self.c,H['MarioApplyY']);execute(self.c,H['MarioApplyX'])
            else:
                self.m[0x8000:0xc000]=self.rom[16:16+0x4000]
                execute(self.c,H['ApplyPlayerPhysicsY']);execute(self.c,H['ApplyPlayerPhysicsX'])
            vx=self.m[H['PlayerXVelocity']]
            if vx:self.m[H['PlayerMovementDirection']]=2 if vx>=128 else 1
            if self.floor and self.m[self.y]>=self.y0 and self.m[H['PlayerYVelocity']]<128:
                self.m[self.y]=self.y0;self.m[H['PlayerInAir']]=0;self.m[H['PlayerYVelocity']]=0;self.m[H['PlayerYSubpixel']]=0
                if 'MarioApplyY'in H:self.m[0x7e11]=0;self.m[0x7e12]=0
            return
        execute(self.c,self.entry,self.traps)
    def values(self):
        values={name:self.m[self.b+off] for name,off in self.mapping.items()}
        values.update(x=self.m[self.x],y=(self.m[self.y]-self.shift)&255)
        if self.game in ['kidicarus','rangers']:
            values['crouch']=int(bool(self.m[self.b+0x1d]))
        return values


def scenarios():
    speeds=[0,8,9,15,16,24,25,27,28,32,33,40]
    for name in ['walk','run','release','reverse','air-turn','chain-jump','down-direction','crouch-direction','duck-jump','duck-jump-release','walk-off','fast-jump-walk-off']:
        yield name,0
    for hold in [1,2,8,25]:
        for speed in speeds:yield f'jump-{hold}',speed


def compare(game,code,V,S):
    rows=[]
    for p in ([0,1]if game=='rangers'else[0,3]if game=='smb2'else[0]):
     for power in ([0]if game=='tetris'else[0,2]if game=='smb2'else[0,1,2]):
      for direction in [1,2]:
       for kind,speed in scenarios():
        if game=='kungfu'and kind in ['walk-off','fast-jump-walk-off']:continue
        port=Port(game,p,power,direction,speed);s=MPU();s.memory[0x8000:]=code
        initial={'PlayerFacingDir':direction,'Player_MovingDir':direction,'AreaType':1,'GameEngineSubroutine':8,
                 'PlayerSize':int(power==0),'Player_CollisionBits':3,'Player_X_Position':128,'Player_Y_Position':144,
                 'Player_Y_HighPos':1,'VerticalForceDown':0x70,'Player_X_Speed':speed if direction==1 else -speed,
                 'Player_XSpeedAbsolute':speed}
        if 'VerticalForce'in port.mapping:initial['VerticalForce']=port.values()['VerticalForce']
        for name,v in initial.items():s.memory[V[name]]=v&255
        first=None;motion=None;matches=0;landed=False;rise=[0,0];sumx=[0,0]
        samples=[]
        for tick in range(130):
            held=direction
            if kind in ['run','release','reverse','air-turn','chain-jump','fast-jump-walk-off']:held|=64
            if kind=='release'and tick>=50:held=0
            if kind=='reverse'and tick>=50:held=(direction^3)|64
            if kind.startswith('jump-'):held=128 if tick<int(kind.split('-')[1])else 0
            if kind=='air-turn'and tick>=30:held=(direction^3)|(128 if tick<55 else 0)
            if kind=='chain-jump'and 30<=tick%65<55:held|=128
            if kind=='down-direction':held=direction|4
            if kind=='crouch-direction':held=4 if tick<10 else direction|4
            if kind in ['duck-jump','duck-jump-release']:
                held=4|(128 if 5<=tick<30 else 0)
                if kind=='duck-jump-release'and tick>=8:held=128 if tick<30 else 0
            if kind=='walk-off'and tick>=30:port.floor=False
            if kind=='fast-jump-walk-off':
                if 65<=tick<90:held|=128
                if landed:port.floor=False
            if not port.floor and s.memory[V['Player_State']]==0:s.memory[V['Player_State']]=2
            for name in ['RunningTimer','JumpSwimTimer','ClimbSideTimer']:
                if s.memory[V[name]]:s.memory[V[name]]-=1
            s.memory[V['SavedJoypadBits']]=held;s.memory[V['Player_X_Position']]=128
            execute(s,S['AuditStep']);port.step(held,tick)
            airborne=s.memory[V['Player_State']]!=0
            if port.floor and s.memory[V['Player_Y_Position']]>=144 and s.memory[V['Player_Y_Speed']]<128:
                for name in ['Player_State','Player_Y_Speed','Player_Y_MoveForce','Player_YMoveForceFractional']:s.memory[V[name]]=0
                s.memory[V['Player_Y_Position']]=144
                if tick>65 and airborne:landed=True
            actual=port.values();wanted={name:s.memory[V[name]]for name in actual if name not in ['x','y','crouch']}
            wanted.update(x=s.memory[V['Player_X_Position']],y=s.memory[V['Player_Y_Position']])
            if 'crouch'in actual:wanted['crouch']=int(bool(s.memory[V['CrouchingFlag']]))
            diff={name:[wanted[name],actual[name]]for name in actual if actual[name]!=wanted[name]}
            if diff and first is None:first={'tick':tick,'held':held,'values_source_port':diff}
            motion_diff={k:v for k,v in diff.items()if k in ['x','y']}
            if motion_diff and motion is None:motion={'tick':tick,'held':held,'values_source_port':motion_diff}
            if not diff:matches+=1
            rise[0]=max(rise[0],144-wanted['y']);rise[1]=max(rise[1],144-actual['y'])
            sumx[0]+=wanted['x']-128;sumx[1]+=actual['x']-128
            if kind in ['jump-1','jump-25','release','reverse']and speed==0 and p==0 and power==0 and direction==1:
                samples.append({'tick':tick,'held':held,'source':wanted,'port':actual})
            s.memory[V['PreviousA_B_Buttons']]=held&192
            if not port.floor and wanted['y']>=208:break
        rows.append({'player':p,'power':power,'direction':direction,'scenario':kind,'speed':speed,'updates':tick+1,
                     'matching_updates':matches,'first_difference':first,'first_motion_difference':motion,
                     'rise_source_port':rise,'travel_source_port':sumx})
        if samples:(OUT/f'{game}-{kind}.json').write_text(json.dumps(samples,indent=2))
    summary={}
    for row in rows:
        item=summary.setdefault(row['scenario'],{'cases':0,'matching_cases':0,'example':None})
        item['cases']+=1;item['matching_cases']+=row['first_difference']is None
        if item['example']is None and row['first_difference']:item['example']=row
    result={'rom_sha256':hashlib.sha256(port.rom).hexdigest(),'cases':len(rows),'updates':sum(r['updates']for r in rows),'matching_cases':sum(r['first_difference']is None for r in rows),
            'matching_motion_cases':sum(r['first_motion_difference']is None for r in rows),'scenarios':summary,'results':rows}
    (OUT/f'{game}.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({'game':game,**{k:v for k,v in result.items()if k!='results'}},indent=2),flush=True)
    return result


def main():
    global CANDIDATE,OUT
    p=argparse.ArgumentParser();p.add_argument('--candidate',action='store_true');p.add_argument('--require-match',action='store_true');p.add_argument('--game',action='append',choices=['kidicarus','rangers','tetris','kungfu','smb2']);a=p.parse_args()
    CANDIDATE=a.candidate
    if CANDIDATE:OUT=ROOT/'build/physics-repair'
    OUT.mkdir(parents=True,exist_ok=True)
    inventory={}
    for game in a.game or NAMES:
        name=NAMES[game]
        root=ROOT/game
        installed=Path('C:/nes',name+'.nes').read_bytes();dist=(root/'dist'/(name+'.nes')).read_bytes()
        sha=hashlib.sha256(installed).hexdigest()
        meta=json.loads((root/'build/manifest.json').read_text());receipt={}if CANDIDATE else json.loads((root/'dist/verification.json').read_text())
        if not CANDIDATE:assert installed==dist and sha==meta['output_sha256']==receipt['rom_sha256'],game+' hash mismatch'
        else:assert hashlib.sha256(dist).hexdigest()==meta['output_sha256'],game+' candidate hash mismatch'
        inventory[game]={'rom_sha256':sha,'dist_sha256':hashlib.sha256(dist).hexdigest(),'matches_dist_manifest_receipt':None if CANDIDATE else installed==dist and sha==meta['output_sha256']==receipt['rom_sha256']}
    (OUT/'inventory.json').write_text(json.dumps(inventory,indent=2))
    source.OUT=OUT/('reference-'+ '-'.join(a.game or ['all']));source.OUT.mkdir(parents=True,exist_ok=True)
    code,V,S=source.reference()
    for game in a.game or ['kidicarus','rangers','tetris','kungfu','smb2']:
        result=compare(game,code,V,S)
        if a.require_match:assert result['cases']==result['matching_cases'],game+' differs from SMB1 source'
    print('PASS source differential comparisons')


if __name__=='__main__':main()
