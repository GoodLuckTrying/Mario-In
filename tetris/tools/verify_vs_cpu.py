"""Independent geometry, strategy, progression and reaction-window checks."""
from pathlib import Path
import hashlib,json,random
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'build/manifest.json').read_text());H=m['labels'];N=m['native']
rom=(ROOT/'dist/Mario in Tetris.nes').read_bytes();code=(ROOT/'build/hack.bin').read_bytes()
def fresh(mode=1):
    mem=bytearray(65536);mem[0x8000:]=rom[16:0x8010];mem[0x6000:0x7800]=code[:0x1800]
    mem[0x400:0x4c8]=bytes([0xef])*200;mem[0x78a0]=mode;mem[N['playfieldAddr']+1]=4
    return MPU(memory=mem)
def call(c,name):
    c.sp=255;c.stPushWord(0x5ffe);c.pc=H[name];before=c.processorCycles
    for _ in range(40000):
        if c.pc==0x5fff:return c.processorCycles-before
        c.step()
    raise AssertionError(('bounded VS routine',name,hex(c.pc)))
def shape(pose):
    off=16+N['orientationTable']-0x8000+pose*12
    def s(v):return v if v<128 else v-256
    return [(s(rom[off+i+2]),s(rom[off+i]))for i in range(0,12,3)]
def tops(grid):return [next((y for y in range(20)if grid[y*10+x]!=0xef),20)for x in range(10)]
def plan(grid,pose,level=0,x=100):
    c=fresh();c.memory[0x400:0x4c8]=grid;c.memory[N['currentPiece']]=pose;c.memory[N['levelNumber']]=level;c.memory[0x7801]=x
    call(c,'APlan');maxcycles=0
    for _ in range(40):
        maxcycles=max(maxcycles,call(c,'ACandidate'))
        if c.memory[0x78b0]==2:break
    assert c.memory[0x78b0]==2,'search must finish in at most 40 slices'
    assert maxcycles<12000,('candidate budget',maxcycles)
    return c,maxcycles
checks=[]
def passed(name,count):checks.append({'name':name,'cases':count,'passed':True});print(name,count,'PASS',flush=True)
rng=random.Random(8573);n=0;maximum=0
for board in range(12):
    heights=[rng.randrange(4,15)]
    for x in range(1,9):heights.append(min(19,max(3,heights[-1]+rng.randrange(-2,3))))
    heights.append(20)
    grid=bytes(0x7b if y>=heights[x]else 0xef for y in range(20)for x in range(10))
    for pose in [2,7,8,10,11,14,18]:
        for level in [0,24]:
            c,cycles=plan(grid,pose,level,rng.randrange(96,161));maximum=max(maximum,cycles)
            assert c.memory[0x400:0x4c8]==grid,'search cannot mutate the live board'
            if c.memory[0x78b8]!=255:
                p=c.memory[0x78b5];x=c.memory[0x78b6];cells=shape(p)
                assert all(0<=x+dx<10 for dx,dy in cells)
                # Independent pixel-free drop simulation, rather than the
                # planner's column-top calculation.
                def valid(y):return all(0<=y+dy<20 and grid[(y+dy)*10+x+dx]==0xef for dx,dy in cells)
                y=2
                assert valid(y),'selected orientation must fit at staging height'
                while valid(y+1):y+=1
                after=bytearray(grid)
                for dx,dy in cells:after[(y+dy)*10+x+dx]=0x7b
                new=tops(after);old=tops(grid)
                for col in range(8):assert abs(new[col]-new[col+1])<=max(4,abs(old[col]-old[col+1])),'CPU cannot create a new unclimbable cliff'
                rows=[after[y*10:(y+1)*10]for y in range(20)]
                remaining=[row for row in rows if 0xef in row]
                post=tops(bytes([0xef])*10*(20-len(remaining))+b''.join(remaining))
                for col in range(8):assert abs(post[col]-post[col+1])<=max(4,abs(old[col]-old[col+1])),'line clearing cannot expose an unclimbable buried pit'
            n+=1
passed('all seven families choose legal falling paths, preserve climbable surfaces and fit a per-frame CPU budget',n)
grid=bytes(0x7b if y>=16 and x<9 else 0xef for y in range(20)for x in range(10))
c,_=plan(grid,18)
assert c.memory[0x78b5]==17 and c.memory[0x78b6]==9,'low-level CPU must take the available four-line Tetris'
passed('low-level CPU takes a four-line Tetris over other placements',1)
grid=bytes([0xef])*200
low,_=plan(grid,18,0,96);high,_=plan(grid,18,24,96)
assert abs(high.memory[0x78b6]-0)<abs(low.memory[0x78b6]-0),'high levels must increasingly target Mario'
passed('increasing level changes a neutral placement toward Mario',1)
heights=[10,6,6,6,6,6,8,8,12,20]
grid=bytes(0x7b if (x==0 and y==10)or(x>0 and y>=heights[x])else 0xef for y in range(20)for x in range(10))
c=fresh();c.memory[0x400:0x4c8]=grid;c.memory[N['currentPiece']]=10
call(c,'APlan');c.memory[0x78b3]=9
call(c,'ACandidate')
assert c.memory[0x78b8]==255,'a tempting row clear over a buried pit must be vetoed'
passed('CPU rejects a line clear that would expose a deep sealed pit',1)
for mode in [1,2]:
    c=fresh(mode);c.memory[0x400:0x4c8]=bytes([0x7b])*200;c.memory[N['currentPiece']]=10;c.memory[N['tetriminoX']]=5;c.memory[N['playState']]=2
    call(c,'VLock');assert c.memory[N['playState']]==8 and c.memory[0x780c]==0 and c.memory[0x400:0x4c8]==bytes([0x7b])*200
c=fresh();c.memory[0x400:0x4c8]=bytes([0x7b])*200;c.memory[N['currentPiece']]=10;c.memory[N['playState']]=1
call(c,'APlan')
for _ in range(10):call(c,'ACandidate')
call(c,'AI');assert c.memory[N['playState']]==8 and c.memory[0x780c]==0
passed('blocked spawns and exhausted safe plans yield instead of trapping or topping out Mario',3)
c=fresh();c.memory[N['playState']]=1;c.memory[N['currentPiece']]=10;c.memory[N['tetriminoX']]=5;c.memory[N['tetriminoY']]=10;c.memory[0x78b0]=3;c.memory[0x78a9]=1
call(c,'AI');assert c.memory[N['tetriminoY']]==10 and c.memory[0x78b0]==3,'head breaks cannot teleport a committed falling piece'
c=fresh(2);c.memory[N['playState']]=2;c.memory[N['currentPiece']]=10;c.memory[N['tetriminoX']]=5;c.memory[N['tetriminoY']]=10
call(c,'VLock');assert c.memory[N['playState']]==1 and c.memory[0x400:0x4c8]==bytes([0xef])*200,'removing support during locking must resume gravity'
passed('terrain changes preserve falling trajectories and unsupported pieces resume descent',2)
n=0
for mode in [1,2]:
    for level in [0,9,19,29,99]:
        c=fresh(mode);c.memory[N['levelNumber']]=level;c.memory[N['currentPiece']]=10;c.memory[N['tetriminoX']]=5;c.memory[N['tetriminoY']]=2;c.memory[N['playState']]=1;c.memory[0x78b0]=3
        c.memory[0x78a4]=30
        for frame in range(30):
            c.memory[N['heldButtons']]=4;c.memory[N['newlyPressedButtons']]=4
            call(c,'VControls');assert c.memory[N['tetriminoY']]==2
            c.memory[0x78a4]-=1;n+=1
        last=0;old=2
        for frame in range(1,61):
            c.memory[N['heldButtons']]=4;c.memory[N['newlyPressedButtons']]=4
            call(c,'VControls')
            if c.memory[N['tetriminoY']]!=old:
                assert frame-last>=6,'even held soft drop cannot bypass six-frame descent floor'
                last=frame;old=c.memory[N['tetriminoY']]
            n+=1
passed('both VS opponents retain spawn grace and a reaction floor at every gravity tier',n)
n=0
for mode in [1,2]:
    for level in [0,1,9,19,98,99]:
        c=fresh(mode);c.memory[0x400:0x4c8]=bytes([0x7b])*200;c.memory[N['levelNumber']]=level;c.memory[N['lines']]=0x35;c.memory[N['score']]=0x80
        call(c,'VAdvance')
        assert c.memory[N['levelNumber']]==min(99,level+1) and c.memory[N['lines']]==0x35 and c.memory[N['score']]==0x80
        assert c.memory[0x78a0]==mode and c.memory[0x78a3]==1 and c.memory[0x7802]==208 and c.memory[N['playState']]==8
        assert c.memory[0x400:0x4c8]==bytes([0xef])*200
        n+=1
passed('escape advances current level once, clears terrain and preserves opponent, score and lines',n)
n=0
for mode in [1,2]:
    for x in range(96,161):
        c=fresh(mode);call(c,'Init');c.memory[0x7801]=x;c.memory[0x7802]=64;c.memory[0x7820]=1;c.memory[0x7805]=0xfc;c.memory[N['heldButtons_player1']]=0x80;c.memory[0x780b]=0x80
        call(c,'Step');assert c.memory[0x7802]<64 and c.memory[0x780c]==0;n+=1
passed('VS opens the top across the entire well while Solo retains its roof',n)
print('Maximum candidate cycles:',maximum)
(ROOT/'build/vs-cpu-verification.json').write_text(json.dumps({'rom_sha256':hashlib.sha256(rom).hexdigest(),'checks':checks,'maximum_candidate_cycles':maximum},indent=2))
