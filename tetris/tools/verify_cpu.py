"""Independent board/shape oracles executed against the actual 6502 code."""
from pathlib import Path
import hashlib,json,random
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'build/manifest.json').read_text());H=m['labels'];N=m['native']
rom=(ROOT/'dist/Mario in Tetris.nes').read_bytes();code=(ROOT/'build/hack.bin').read_bytes()
def fresh():
    mem=bytearray(65536);mem[0x8000:]=rom[16:0x8010];mem[0x6000:0x7800]=code[:0x1800]
    mem[0x400:0x4c8]=bytes([0xef])*200
    return MPU(memory=mem)
def call(c,name,a=0,x=0):
    c.a=a;c.x=x;c.sp=0xff;c.stPushWord(0x5ffe);c.pc=H[name]
    for _ in range(30000):
        if c.pc==0x5fff:return c.a
        c.step()
    raise AssertionError('Routine did not return: '+name)
checks=[]
def passed(name,count):checks.append({'name':name,'cases':count,'passed':True});print(name,count,'PASS',flush=True)
c=fresh();rng=random.Random(4673);grid=[0x7b if rng.randrange(4)==0 else 0xef for _ in range(200)];c.memory[0x400:0x4c8]=grid
n=0
for y in range(32,225):
    for x in range(80,193):
        expected=not(96<=x<176 and 48<=y<208) or grid[(y-48)//8*10+(x-96)//8]!=0xef
        assert bool(call(c,'Tile',y,x))==expected,(x,y);n+=1
passed('pixel lookup agrees with native locked grid and all four well bounds',n)
n=0
for _ in range(1000):
    x=rng.randrange(96,161);y=rng.randrange(64,209);c.memory[0x7801]=x;c.memory[0x7802]=y
    expected=any(grid[row*10+col]!=0xef for row in range((y-15-48)//8,(y-1-48)//8+1) for col in range((x+2-96)//8,(x+13-96)//8+1))
    assert bool(call(c,'Body'))==expected,(x,y);n+=1
passed('full Mario body probes include middle cells at unaligned positions',n)
shapes=[]
for pose in range(19):
    off=N['orientationTable']+pose*12
    def signed(v):return v if v<128 else v-256
    shapes.append([(96+(5+signed(c.memory[off+i+2]))*8,48+(10+signed(c.memory[off+i]))*8) for i in range(0,12,3)])
n=0
for pose,shape in enumerate(shapes):
    for x,y in shape:
        for state in [1,2]:
            c=fresh();c.memory[N['playState']]=state;c.memory[N['currentPiece']]=pose;c.memory[N['tetriminoX']]=5;c.memory[N['tetriminoY']]=10
            c.memory[0x7801]=x-4;c.memory[0x7802]=y+2;c.memory[0x780a]=y-3;c.memory[0x7805]=2
            call(c,'Contacts')
            assert c.memory[0x780c]==0 and c.memory[0x7811]==1 and c.memory[N['currentPiece']]==19 and c.memory[N['playState']]==8
            assert c.memory[0x400:0x4c8]==bytes([0xef])*200 and c.memory[0x7805]>=128
            n+=1
passed('every mino in all 19 orientations can be stomped before locking, with a bounce',n)
n=0
for pose,shape in enumerate(shapes):
    for x in range(100,161,4):
        for y in range(96,161,4):
            c=fresh();c.memory[N['playState']]=1;c.memory[N['currentPiece']]=pose;c.memory[N['tetriminoX']]=5;c.memory[N['tetriminoY']]=10
            c.memory[0x7801]=x;c.memory[0x7802]=y;c.memory[0x780a]=y;c.memory[0x7805]=0xfc
            head=any(x+2<bx+8 and x+14>bx and y-16<by+8 and y-12>by for bx,by in shape)
            call(c,'Contacts');assert bool(c.memory[0x780c])==head,(pose,x,y,shape);n+=1
passed('head hits use occupied cells, preserving gaps and empty shape corners',n)
n=0
for pose,shape in enumerate(shapes):
    for x,y in shape:
        c=fresh();c.memory[N['playState']]=3;c.memory[N['currentPiece']]=pose;c.memory[N['tetriminoX']]=5;c.memory[N['tetriminoY']]=10
        c.memory[0x7801]=x-4;c.memory[0x7802]=y+2;c.memory[0x780a]=y-3;c.memory[0x7805]=2
        call(c,'Contacts');assert c.memory[0x7811]==0 and c.memory[N['currentPiece']]==pose and c.memory[N['playState']]==3;n+=1
passed('stomps cannot destroy solidified pieces',n)
n=0
for row in range(18):
    for x in range(96,161):
        for queued in [0,max(0,row-1),32]:
            c=fresh();call(c,'Init');c.memory[0x7801]=x;c.memory[0x7802]=72+row*8
            c.memory[0x400+row*10:0x400+(row+1)*10]=bytes([0x7b])*10
            if row<17:c.memory[0x400+(row+3)*10:0x400+(row+4)*10]=bytes([0x7c])*10
            before=bytearray(c.memory[0x400:0x4c8]);expected=bytearray(before)
            for col in range((x+2-96)//8,(x+13-96)//8+1):expected[row*10+col]=0xef
            c.memory[N['vramRow']]=queued;c.memory[N['player1_vramRow']]=queued
            c.memory[N['heldButtons_player1']]=0x80
            call(c,'Step')
            assert c.memory[0x780c]==0 and c.memory[0x7802]==72+row*8,'settled head hits must bonk safely'
            assert c.memory[0x400:0x4c8]==expected,(row,x,queued)
            assert c.memory[N['vramRow']]==min(row,queued) and c.memory[N['player1_vramRow']]==min(row,queued)
            assert c.memory[0x7811]==0 and c.memory[N['score']]==0 and c.memory[N['lines']]==0
            n+=1
passed('head breaks touch only settled cells above Mario and coalesce all redraw positions',n)
for x in range(96,161):
    c=fresh();call(c,'Init');c.memory[0x7801]=x;c.memory[0x7802]=64;c.memory[0x7820]=1
    c.memory[0x7805]=0xfc;c.memory[0x780b]=0x80;c.memory[N['heldButtons_player1']]=0x80
    call(c,'Step');assert c.memory[0x7802]==64 and c.memory[0x780c]==0 and c.memory[0x400:0x4c8]==bytes([0xef])*200
passed('head breaking cannot damage or escape the top boundary',65)
c=fresh();call(c,'Init');c.memory[N['currentPiece']]=19
for direction,expected in [(2,96),(1,160),(2,96)]:
    c.memory[N['heldButtons_player1']]=direction|0x40
    for _ in range(180):
        call(c,'Step');assert 96<=c.memory[0x7801]<=160 and 64<=c.memory[0x7802]<=208
    assert c.memory[0x7801]==expected
passed('walking and running remain inside both walls',540)
peaks=[]
for hold in [1,24]:
    c=fresh();call(c,'Init');peak=208
    for f in range(100):
        c.memory[N['heldButtons_player1']]=0x80 if f<hold else 0
        call(c,'Step');peak=min(peak,c.memory[0x7802]);assert 64<=c.memory[0x7802]<=208
    assert c.memory[0x7802]==208 and c.memory[0x7820]==0
    peaks.append(peak)
assert peaks[1]<peaks[0]-12,peaks
passed('held A gives a higher jump; both jumps land on the floor',200)
c=fresh();call(c,'Init');call(c,'Die')
for _ in range(79):call(c,'DeathStep');assert c.memory[0x7802]<=209
assert c.memory[N['playState']]==10 and c.memory[0x780c]==80
passed('death finishes in native game over without vertical wrapping',79)
report={'rom_sha256':hashlib.sha256(rom).hexdigest(),'checks':checks}
(ROOT/'build/cpu-verification.json').write_text(json.dumps(report,indent=2))
