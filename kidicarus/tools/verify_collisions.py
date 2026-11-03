"""Exercise player collision/contact code against geometric terrain fixtures."""
from pathlib import Path
import argparse, hashlib, json
from py65.devices.mpu6502 import MPU
from verify_physics import run, set_values

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--previous',action='store_true')
args=parser.parse_args()
manifest=json.loads((ROOT/('dist/build-manifest.json' if args.previous else 'build/manifest.json')).read_text())
labels=manifest['labels']
rom=Path('C:/nes/Mario In/Mario in Kid Icarus.nes').read_bytes() if args.previous else (ROOT/'dist/Mario in Kid Icarus.nes').read_bytes()
assert hashlib.sha256(rom).hexdigest()==manifest['output_sha256']
bank=rom[16+8*16384:16+9*16384]
failures=[]
cases=0

def cpu(power=0,scroll=0):
    c=MPU();c.memory[0x8000:0xC000]=bank;c.memory[0xC000:]=rom[16+15*16384:]
    for name,start,size in [('BRIDGES',0x6100,0x700),('SCROLL',0x6A00,0x400),('VBLANK',0x6E00,0x100)]:
        key=f'__{name}_LOAD__'
        if key in labels:
            offset=labels[key]-0x8000;c.memory[start:start+size]=bank[offset:offset+size]
    set_values(c,{0x6800:0x4D,0x6801:2,0x680B:1,0x680C:1,0x6814:1,0x6815:8,
                  0x6804:power,0x681B:0x70,0x681A:0x70,0x6820:0xFF,0xA0:2,0x6837:2,
                  0xFD:scroll,0x6839:scroll,0x721:0x80,0xA6:15})
    return c

def update(c,tile,held=0):
    set_values(c,{0x16:held})
    def terrain(c):
        value=tile(c.y,c.a)
        set_values(c,{0x6823:value,0x6826:c.a,0x6827:c.y,0:0,1:5})
        c.a=value;c.y=0;c.p=(c.p&~0x82)|(2 if value==0 else 0)|(value&0x80)
    run(c,labels['MarioUpdate'],{labels['TileAt']:terrain,labels['NativeTerrainEffect']:lambda c:None})

def check(name,condition,details):
    global cases
    cases+=1
    if not condition and len(failures)<25:failures.append({'case':name,'details':details})

# Approach a ledge with the lower seven pixels below its surface. A side
# collision must stop Mario before his foot can enter and become grounded.
for power in range(3):
    for scroll in range(16):
        for direction in (-1,1):
            c=cpu(power,scroll)
            set_values(c,{0x723:52 if direction==1 else 106,0x720:156-scroll,0x6805:2,
                          0x6818:1,0x6806:direction*40,0x6808:40,0x681E:int(power>0)})
            clear=True
            for tick in range(20):
                update(c,lambda x,y:0x59 if 64<=x<96 and 160<=y+scroll<192 else 0,(1 if direction==1 else 2)|0x40)
                x=c.memory[0x723];y=c.memory[0x720]+scroll
                top=y-(20 if power else 6)
                if x+9>=64 and x-2<96 and y+7>=160 and top<192:clear=False;break
            check('ledge-side',clear,{'power':power,'scroll':scroll,'direction':direction,'tick':tick,'x':x,'y':y})
        for speed in (1,2,3,4):
            c=cpu(power,scroll)
            set_values(c,{0x723:80,0x720:140-scroll,0x6805:2,0x6818:speed})
            for _ in range(24):update(c,lambda x,y:0x50 if y+scroll>=160 else 0)
            check('land-top',c.memory[0x720]+scroll==152 and c.memory[0x6805]==0,
                  {'power':power,'scroll':scroll,'speed':speed,'y':c.memory[0x720]+scroll})
        for depth in range(1,8):
            c=cpu(power,scroll);set_values(c,{0x723:80,0x720:152+depth-scroll,0x6805:0})
            update(c,lambda x,y:0x50 if y+scroll>=160 else 0)
            check('resolve-embedded-feet',c.memory[0x720]+scroll==152,{'power':power,'scroll':scroll,'depth':depth})
            c=cpu(power,scroll);set_values(c,{0x723:80,0x720:152+depth-scroll,0x6805:2,0x6818:2})
            update(c,lambda x,y:0x40 if 160<=y+scroll<176 else 0)
            check('one-way-from-below',c.memory[0x720]+scroll>=154+depth,
                  {'power':power,'scroll':scroll,'depth':depth,'y':c.memory[0x720]+scroll})

for power in range(3):
    for offset in (-8,0,8):
        c=cpu(power);set_values(c,{0x723:128+offset,0x720:132,0x682F:130,0x6805:2,0x6818:2,
                                 0x681E:int(power>0),0x7C0:148,0x7C3:128,0x7C1:0x11})
        c.x=0xC0;run(c,labels['MarioContact'])
        check('stomp-before-damage',c.memory[0x6804]==power and c.memory[0x721]&0x40==0,
              {'power':power,'offset':offset,'form':c.memory[0x6804]})
        c.x=0xC0;run(c,labels['TryStomp'])
        check('head-crossing-bounce',c.p&1==0 and c.memory[0x6818]==0xFC,{'power':power,'offset':offset})
    c=cpu(power);set_values(c,{0x723:128,0x720:156,0x682F:157,0x6805:1,0x6818:0xFC,0x7C0:148,0x7C3:128})
    c.x=0xC0;run(c,labels['TryStomp'])
    check('no-rising-stomp',c.p&1==1,{'power':power})
    c=cpu(power);set_values(c,{0x723:128,0x720:148,0x681E:int(power>0),0x7C0:148,0x7C3:128,
                             0x7C1:0x11,0x3E:100,0x14F:2})
    c.x=0xC0;run(c,labels['MarioContact'])
    check('falling-mallet-pickup',c.memory[0x6804]==power and c.memory[0x14F]==3 and c.memory[0x7C1]==0,
          {'power':power,'form':c.memory[0x6804],'mallets':c.memory[0x14F]})

# Adjacent enemies are processed one at a time by the native engine. The
# first bounce changes VY before the second enemy's contact and hit checks.
for power in [1,2]:
    for direction in [-1,1]:
        c=cpu(power)
        set_values(c,{0x723:128,0x720:160,0x682F:157,0x6805:2,0x6818:3,
                      0x681E:1,0x7C0:176,0x7C3:128-8*direction,0x7C1:0x11,
                      0x7C8:176,0x7CB:128+8*direction,0x7C9:0x11})
        c.x=0xC0;run(c,labels['TryStomp'])
        c.x=0xC8;run(c,labels['MarioContact'])
        check('adjacent-contact-after-bounce',c.memory[0x6804]==power,
              {'power':power,'direction':direction,'remaining_form':c.memory[0x6804]})
        c.x=0xC8;run(c,labels['TryStomp'])
        check('adjacent-same-frame-stomp',c.p&1==0,
              {'power':power,'direction':direction,'carry':c.p&1})
        # Subsequent rising frames protect the bounce but cannot kill enemies.
        c.memory[0x68C7]=0
        set_values(c,{0x720:164,0x682F:168,0x7C8:160})
        c.x=0xC8;run(c,labels['MarioContact'])
        check('bounce-contact-grace',c.memory[0x6804]==power,{'power':power,'direction':direction})
        c.x=0xC8;run(c,labels['TryStomp'])
        check('bounce-grace-is-not-star',c.p&1==1,{'power':power,'direction':direction})
        set_values(c,{0x68C6:0,0x6805:0,0x6818:0,0x720:160,0x7C8:160})
        c.x=0xC8;run(c,labels['MarioContact'])
        check('contact-damage-after-grace',c.memory[0x6804]==0,{'power':power,'direction':direction})
for power in range(3):
    for offset in [-15,-14,14,15]:
        for motion in [-4,0,4,8]:
            c=cpu(power)
            set_values(c,{0x723:128+offset,0x720:164,0x682F:160+motion,
                          0x6805:2,0x6818:3,0x7C0:176,0x7C3:128,0x7C1:0x11})
            c.x=0xC0;run(c,labels['TryStomp'])
            check('descending-edge-stomp',c.p&1==0 and c.memory[0x6818]==0xFC,
                  {'power':power,'offset':offset,'enemy_motion':motion})

report={'cases':cases,'failures':failures,'rom_sha256':hashlib.sha256(rom).hexdigest()}
(ROOT/'build'/('collision-before.json' if args.previous else 'collision-results.json')).write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2)[:6500])
if args.previous:assert failures,'Regression fixtures must detect the previous build defects'
else:assert not failures,'Collision/contact regression failed'
