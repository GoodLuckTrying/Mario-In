"""Occupied-cell collision and adaptive CPU regression oracles."""
from pathlib import Path
import json,hashlib
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'build/manifest.json').read_text());H=m['labels'];N=m['native']
rom=(ROOT/'dist/Mario in Tetris.nes').read_bytes();code=(ROOT/'build/hack.bin').read_bytes()
def fresh(mode=2):
    mem=bytearray(65536);mem[0x8000:]=rom[16:0x8010];mem[0x6000:0x7800]=code[:0x1800]
    mem[0x400:0x4c8]=bytes([0xef])*200;mem[0x78a0]=mode;mem[N['playfieldAddr']+1]=4
    mem[N['playState']]=1;mem[N['tetriminoX']]=5;mem[N['tetriminoY']]=10
    return MPU(memory=mem)
def call(c,name):
    c.sp=255;c.stPushWord(0x5ffe);c.pc=H[name];before=c.processorCycles
    for _ in range(40000):
        if c.pc==0x5fff:return c.a,c.processorCycles-before
        c.step()
    raise AssertionError((name,hex(c.pc)))
def cells(p,px=5,py=10):
    off=16+N['orientationTable']-0x8000+p*12
    def s(v):return v if v<128 else v-256
    return [(96+(px+s(rom[off+i+2]))*8,48+(py+s(rom[off+i]))*8)for i in range(0,12,3)]
def overlap(x,y,shape):return any(x+2<bx+8 and x+14>bx and y-15<by+8 and y>by for bx,by in shape)
checks=[]
def passed(name,count):checks.append({'name':name,'cases':count,'passed':True});print(name,count,'PASS',flush=True)
n=0
for p in range(19):
    shape=cells(p);c=fresh();c.memory[N['currentPiece']]=p
    for x in range(96,161,4):
        for y in range(104,161,4):
            c.memory[0x7801]=x;c.memory[0x7802]=y
            got,_=call(c,'ActiveBody');assert bool(got)==overlap(x,y,shape),(p,x,y)
            n+=1
passed('live-piece collision matches all occupied cells and preserves shape gaps',n)
n=0
for p in range(19):
    shape=cells(p)
    for feet in sorted({by+8 for bx,by in shape}):
        touching=[bx for bx,by in shape if feet>by and feet-15<by+8]
        for direction,start,target in [(1,96,min(touching)-14),(2,160,max(touching)+6)]:
            c=fresh();c.memory[N['currentPiece']]=p;c.memory[0x7801]=start;c.memory[0x7802]=feet
            for _ in range(32):
                c.memory[0x7821]=0x30 if direction==1 else 0xd0
                call(c,'MoveX');assert not overlap(c.memory[0x7801],feet,shape)
                n+=1
            assert c.memory[0x7801]==target,(p,feet,direction,c.memory[0x7801],target)
passed('walking cannot enter any live-piece side from either direction',n)
n=0;maximum=0
for p in range(19):
    shape=cells(p)
    for direction in [1,2]:
        feet=max(by for bx,by in shape)+8
        touching=[bx for bx,by in shape if feet>by and feet-15<by+8]
        start=max(touching)-2 if direction==1 else min(touching)-6
        c=fresh();c.memory[N['currentPiece']]=p;c.memory[0x7801]=start;c.memory[0x7802]=feet;c.memory[0x780a]=feet
        c.memory[0x7b07]=4 if direction==1 else 6;c.memory[0x7b08]=10;c.memory[0x7b09]=p;c.memory[0x7b06]=1
        _,cycles=call(c,'PieceSides');maximum=max(maximum,cycles)
        assert not overlap(c.memory[0x7801],feet,shape) and c.memory[0x780c]==0 and c.memory[0x7811]==0
        assert (c.memory[0x7801]>start)==(direction==1),(p,direction,start,c.memory[0x7801])
        assert c.memory[N['tetriminoX']]==5 and c.memory[0x400:0x4c8]==bytes([0xef])*200
        n+=1
passed('moving every piece shape pushes Mario sideways without head damage or terrain changes',n)
c=fresh();c.memory[N['currentPiece']]=10;c.memory[N['tetriminoX']]=8;c.memory[0x7801]=158;c.memory[0x7802]=144;c.memory[0x780a]=144
c.memory[0x7b07]=7;c.memory[0x7b08]=10;c.memory[0x7b09]=10;c.memory[0x7b06]=1
call(c,'PieceSides');assert c.memory[0x7801]==158 and c.memory[N['tetriminoX']]==7 and c.memory[0x780c]==0,'a wall pin must reject the piece move instead of teleporting Mario through it'
c=fresh();c.memory[N['currentPiece']]=10;c.memory[N['tetriminoX']]=6;c.memory[0x7801]=142;c.memory[0x7802]=144;c.memory[0x780a]=144
c.memory[0x7b07]=5;c.memory[0x7b08]=10;c.memory[0x7b09]=10;c.memory[0x7b06]=1;c.memory[0x400+11*10+8]=0x7b
call(c,'PieceSides');assert c.memory[0x7801]==142 and c.memory[N['tetriminoX']]==5 and c.memory[0x780c]==0,'a push cannot cross a settled wall'
passed('walls and settled blocks stop a push without crushing or teleporting Mario',2)
def hunt(level,x=160,vy=0xfc,y=208,px=5,py=5):
    c=fresh(1);c.memory[N['currentPiece']]=10;c.memory[N['levelNumber']]=level;c.memory[N['tetriminoX']]=px;c.memory[N['tetriminoY']]=py
    c.memory[0x7801]=x;c.memory[0x7802]=y;c.memory[0x7805]=vy;c.memory[0x78b0]=3;c.memory[0x78b8]=8
    call(c,'AHeights')
    return c
for level in range(10):
    c=hunt(level);call(c,'AHunt');assert c.memory[N['newlyPressedButtons']]==0
passed('levels zero through nine retain pure Tetris plans',10)
for level in [10,19,29,99]:
    for x,direction in [(96,2),(160,1)]:
        c=hunt(level,x);_,cycles=call(c,'AHunt');maximum=max(maximum,cycles)
        assert c.memory[N['newlyPressedButtons']]==direction and c.memory[N['tetriminoX']]==5 and c.memory[N['tetriminoY']]==5
        assert c.memory[0x78b0]==3 and c.memory[0x78b8]!=255
passed('committed falling pieces track Mario in both directions above level nine',8)
c=hunt(19,132,2,100,5,8);call(c,'AHunt');assert c.memory[N['newlyPressedButtons']]==1 and c.memory[0x7b11]>0,'a descending Mario over the piece triggers an evasive move'
c=hunt(19);c.memory[0x400+5*10+6]=0x7b
call(c,'AHeights')
call(c,'AHunt');assert c.memory[0x7b18]==2,'blocked pursuit schedules an alternate direction'
call(c,'AHunt');assert c.memory[N['newlyPressedButtons']]==2 and c.memory[N['tetriminoX']]==5,'the next decision safely diverts around the obstacle'
passed('CPU dodges a stomp and diverts around a blocked pursuit path',3)
rates=[]
for level in [10,19,29,34,99]:
    c=hunt(level);call(c,'AHunt');rates.append(c.memory[0x7b10])
assert rates==[30,21,11,6,6],rates
assert maximum<12000,maximum
passed('active targeting increases gradually with a bounded CPU budget',5)
print('Maximum push/hunt cycles:',maximum)
(ROOT/'build/updates-cpu-verification.json').write_text(json.dumps({'rom_sha256':hashlib.sha256(rom).hexdigest(),'checks':checks,'maximum_cycles':maximum},indent=2))
