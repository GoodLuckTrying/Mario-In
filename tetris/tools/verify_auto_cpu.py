"""Auto-Classic: legal plans, no Mario influence, and native loss/progression."""
from pathlib import Path
import hashlib,json,random
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'build/manifest.json').read_text());H=m['labels'];N=m['native']
rom=(ROOT/'dist/Mario in Tetris.nes').read_bytes();code=(ROOT/'build/hack.bin').read_bytes()
def fresh(mode=3):
    mem=bytearray(65536);mem[0x8000:]=rom[16:0x8010];mem[0x6000:0x7800]=code[:0x1800]
    mem[0x400:0x4c8]=bytes([0xef])*200;mem[0x78a0]=mode;mem[N['playfieldAddr']+1]=4
    mem[N['playState']]=1;mem[N['tetriminoX']]=5;mem[N['vramRow']]=32
    return MPU(memory=mem)
def call(c,name):
    c.sp=255;c.stPushWord(0x5ffe);c.pc=H[name]if isinstance(name,str)else name;before=c.processorCycles
    for _ in range(60000):
        if c.pc==0x5fff:return c.processorCycles-before
        c.step()
    raise AssertionError((name,hex(c.pc)))
def cells(p):
    a=16+N['orientationTable']-0x8000+p*12
    def signed(v):return v if v<128 else v-256
    return [(signed(rom[a+i+2]),signed(rom[a+i]))for i in range(0,12,3)]
def plan(grid,p,level,x):
    c=fresh();c.memory[0x400:0x4c8]=grid;c.memory[N['currentPiece']]=p;c.memory[N['levelNumber']]=level;c.memory[0x7801]=x
    call(c,'APlan');maximum=0
    for _ in range(40):
        maximum=max(maximum,call(c,'ACandidate'))
        if c.memory[0x78b0]==2:break
    assert c.memory[0x78b0]==2
    assert c.memory[0x400:0x4c8]==grid
    return c,maximum
checks=[]
def passed(name,n):
    checks.append({'name':name,'passed':True,'cases':n});print(name,n,'PASS',flush=True)
rng=random.Random(332);count=0;maxcycles=0
for board in range(10):
    heights=[rng.randrange(9,20)for _ in range(10)]
    grid=bytes(0x7b if y>=heights[x]else 0xef for y in range(20)for x in range(10))
    for p in [2,7,8,10,11,14,18]:
        reference=None
        for level,x in [(0,96),(10,160),(29,128),(99,96)]:
            c,cycles=plan(grid,p,level,x);maxcycles=max(maxcycles,cycles)
            result=bytes(c.memory[0x78b5:0x78b9])
            if reference is None:reference=result
            else:assert result==reference,'Auto never targets Mario, even at high levels'
            assert c.memory[0x78b8]!=255,'a legal uneven board has at least one plan'
            p1=c.memory[0x78b5];px=c.memory[0x78b6];shape=cells(p1)
            def valid(y):return all(0<=px+dx<10 and 0<=y+dy<20 and grid[(y+dy)*10+px+dx]==0xef for dx,dy in shape)
            assert valid(2),'selected pose fits at staging height'
            y=2
            while valid(y+1):y+=1
            assert valid(y)and not valid(y+1),'independent cell drop reaches a supported landing'
            count+=1
assert maxcycles<12000,('per-frame search budget',maxcycles)
passed('Auto plans all seven families legally on uneven boards without level or Mario-position influence',count)
for mode in [1,3]:
    c=fresh(mode);c.memory[0x400:0x4c8]=bytes(0x7b if y>=(4 if x==3 else 8)else 0xef for y in range(20)for x in range(10))
    c.memory[N['currentPiece']]=17;call(c,'APlan');c.memory[0x78b2]=17;c.memory[0x78b3]=3
    call(c,'ACandidate')
    assert (c.memory[0x78b8]!=255)==(mode==3),'classic accepts legal high cliffs that VS vetoes for Mario'
passed('Auto bypasses the VS climb-height veto while VS retains it',2)
for level in [0,9,19,29,99]:
    grid=bytes(0x7b if y>=16 and x<9 else 0xef for y in range(20)for x in range(10))
    c,_=plan(grid,18,level,100)
    assert (c.memory[0x78b5],c.memory[0x78b6])==(17,9),'Auto takes an available four-line Tetris'
passed('Auto chooses available Tetrises at every gravity tier',5)
for level in [0,5,9,10,19,29]:
    for lines in [0,6,9,99,198]:
        for complete in range(5):
            a=fresh();b=fresh()
            for c in [a,b]:
                c.memory[N['levelNumber']]=level;c.memory[N['completedLines']]=complete
                c.memory[N['lines']]=(lines%10)|((lines//10%10)<<4);c.memory[N['lines']+1]=lines//100
                c.memory[N['holdDownPoints']]=10
            call(a,'VStats');call(b,N['playState_updateLinesAndStatistics'])
            assert a.memory[:0x600]==b.memory[:0x600],'Auto scoring and level thresholds equal native Tetris'
passed('Auto scoring and starting-level thresholds exactly match the native engine',150)
for kind in ['blocked','exhausted','unreachable']:
    c=fresh();c.memory[N['currentPiece']]=10
    if kind=='blocked':
        c.memory[0x400:0x4c8]=bytes([0x7b])*200
        call(c,'APlan')
        assert c.memory[0x78b0]==3 and c.memory[N['tetriminoY']]==0,'blocked spawn is never teleported'
        call(c,'VLock');assert c.memory[N['playState']]==10,'classic blocked spawn loses through native top-out'
    else:
        c.memory[0x78b0]=2;c.memory[0x78b8]=255 if kind=='exhausted'else 0
        c.memory[0x78bc]=95;c.memory[0x78b5]=10;c.memory[0x78b6]=5
        call(c,'AI')
        assert c.memory[0x78b0]==3 and c.memory[N['playState']]==1 and c.memory[N['currentPiece']]==10,'failed planning drops the actual piece instead of deleting it'
passed('Auto preserves blocked, exhausted and unreachable pieces and uses native top-out',3)
(ROOT/'build/auto-cpu-verification.json').write_text(json.dumps({'rom_sha256':hashlib.sha256(rom).hexdigest(),'checks':checks,'maximum_candidate_cycles':maxcycles},indent=2))
