"""Execute assembled hooks with real mapper banking and the exact Rev 1 combat code."""
from pathlib import Path
import json,sys
from py65.devices.mpu6502 import MPU
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'punchout'
sys.path.insert(0,str(ROOT/'tools'))
from audit_all_physics import execute
from native_port_common import sha
M=json.loads((P/'build/manifest.json').read_text());H=M['labels']
ROM=(P/'dist'/f"{M['name']}.nes").read_bytes();BASE=Path(M['base_rom']).read_bytes()
class Memory:
    def __init__(self,rom=ROM,bank=7):
        self.ram=bytearray(65536);self.rom=rom;self.bank=bank;self.ppu=bytearray(0x4000);self.addr=0;self.high=True;self.writes=[];self.regs={}
        self.ram[0xd]=bank
    def __getitem__(self,a):
        if isinstance(a,slice):return [self[i]for i in range(*a.indices(65536))]
        a&=65535
        if a>=0x8000:
            offset=(self.bank*8192+a-0x8000)if a<0xa000 else (13*8192+a-0xa000)
            return self.rom[16+offset]
        if a==0x2002:self.high=True;return 0
        return self.ram[a]
    def __setitem__(self,a,v):
        if isinstance(a,slice):
            for i,value in zip(range(*a.indices(65536)),v):self[i]=value
            return
        a&=65535;v&=255
        if a==0xafff:self.bank=v&15;self.regs[a]=v
        elif a==0x2006:
            self.addr=(v<<8)if self.high else ((self.addr&0xff00)|v);self.high=not self.high
        elif a==0x2007:
            self.ppu[self.addr&0x3fff]=v;self.writes.append((self.addr&0x3fff,v));self.addr+=(32 if self.ram[0x2000]&4 else 1)
        elif a>=0x8000:self.regs[a]=v
        else:self.ram[a]=v
def run(mem,label,traps=None):
    cpu=MPU(memory=mem);execute(cpu,H[label]if isinstance(label,str)else label,traps or {});return cpu
def initialized(bank=7):
    m=Memory(bank=bank);run(m,'ResetMario',{0xa1c4:lambda c:None});return m
def combat_fixture(m,hp=96,defense=0,kind=1):
    # Complete native variables used by normal hit resolution and the KO pipeline.
    m.ram[0x300:0x600]=bytes(0x300)
    for a,v in {0x50:1,0x51:0,0x58:0,0x74:2,0x75:5,0x76:0xff,0x77:8,0x90:1,0x91:0,
                0xb5:12,0xb6:0,0xb7:0,0xb8:0,0xb9:0,0xbc:1,0x392:96,0x391:96,
                0x399:hp,0x398:hp,0x5b0:3,0x5b1:3,0x5d7:15,0x580:24,0x323:9,0x324:1,
                0x6016:kind,0x6023:0}.items():m.ram[a]=v
    m.ram[0xb6+kind]=defense
def check():
    checks=[]
    def passed(name,count):checks.append(dict(name=name,passed=True,cases=count))
    # All positive frames, followed by reverse order, exercise pose clearing as well.
    art=json.loads((P/'build/art-map.json').read_text())['frames'];m=initialized(11);m.ram[0x2000]=4
    previous=set()
    for n in list(range(98))+list(reversed(range(98))):
        m.bank=11;m.ram[0xd]=11;m.ram[0x61]=n;m.ram[0x60]=0x80
        before=bytes(m.ram[0x200:0x300]);saved=m.ram[0xe]
        run(m,'PrepareMario');assert m.bank==11 and m.ram[0xe]==saved
        run(m,'RenderMario');assert m.bank==11 and m.ram[0x69]==2 and m.ram[0x60]==0
        assert bytes(m.ram[0x200:0x300])==before,'hardware opponent OAM changed'
        expected=dict(art[n]['tiles']);now=set(expected)
        for a,t in expected.items():assert m.ppu[a]==t,(n,hex(a),m.ppu[a],t)
        for a in previous-now:assert m.ppu[a]==0xfe,(n,'stale old pose',hex(a))
        for a in now|previous:assert m.ram[0x6400+(a&1023)]==expected.get(a,0xfe),(n,'fireball underlay',hex(a))
        previous=now
    passed('196 pose transitions: nametable output, no trails, mapper restore, private underlay, OAM preserved',196)
    # Decode the actual linked commands and CHR independently of art-map.json.
    # Cropped native Mac redraws must never become Mario's body position.
    bank6=ROM[16+6*8192:16+7*8192];chr2=ROM[16+0x20000+8192:16+0x20000+12288]
    for n in range(98):
        ptr=int.from_bytes(bank6[0x11+n*2:0x13+n*2],'little')-0x8000;pixels=[]
        while bank6[ptr]:
            address=bank6[ptr]*256+bank6[ptr+1];size=bank6[ptr+2];ptr+=3
            for k in range(size):
                t=bank6[ptr];ptr+=1;a=address+k*32;b=chr2[t*16:t*16+16]
                for y in range(8):
                    for x in range(8):
                        if ((b[y]|b[y+8])>>(7-x))&1:pixels.append(((a%32)*8+x,((a&1023)//32)*8+y))
        if n in range(0x40,0x44):assert not pixels;continue
        assert pixels
        if n!=0x3a:assert max(y for x,y in pixels)==215,('Mario feet jumped between animation commands',hex(n))
        if 0x2a<=n<=0x35:
            assert max(y for x,y in pixels)-min(y for x,y in pixels)>=29,'ordinary recoil cannot be horizontal knockdown art'
        if n==0x3a:assert max(y for x,y in pixels)<=215 and max(y for x,y in pixels)-min(y for x,y in pixels)<16,'actual knockdown retains its lying pose'
    passed('All 98 linked poses respect the floor anchor; 12 ordinary recoil poses stand upright and true knockdown stays horizontal',98)
    sys.path.insert(0,str(P/'tools'));from analyze_art import frame
    reserved={t for n in range(128,175)for a,t in frame(n)['writes']}
    count=0
    for n in range(128,175):
        candidate=initialized(11);ref=Memory(BASE,11)
        for mem in (candidate,ref):
            mem.ram[0x2000]=4;mem.ram[0x61]=n;mem.ram[0x60]=0x80
        run(candidate,'PrepareMario');run(candidate,'RenderMario')
        run(ref,0x8280);run(ref,0x8020)
        assert candidate.ppu==ref.ppu,('referee command output differs from the native renderer',hex(n))
        assert dict(ref.writes)==dict(frame(n)['writes']),('art decoder missed a native referee control/run',hex(n))
        count+=1
    passed('All 47 referee/count/announcement commands match actual original 6502 VRAM writes, including nested runs',count)
    for t in reserved:
        assert ROM[16+0x20000+8192+t*16:16+0x20000+8192+(t+1)*16]==BASE[16+0x20000+4096+t*16:16+0x20000+4096+(t+1)*16]
    passed('All referee tiles coexist unchanged with Mario in the combined background bank',len(reserved))
    chrbase=16+0x20000
    assert ROM[chrbase:chrbase+4096]==BASE[chrbase:chrbase+4096],'FD atlas must preserve the native referee, HUD and font'
    passed('Native FD atlas byte-identical; replacement portrait is isolated from the referee',256)
    count=0
    for hp in (1,3,4,5,15,48,96):
        for defense in (0,1,3,4,8,0x80,0xff):
            for kind in (1,3):
                for stance in (0,8,0x80,0xff):
                    m=initialized();combat_fixture(m,hp,defense,kind);m.ram[0x76]=stance;m.ram[0x77]=stance
                    preserved=bytes(m.ram[a]for a in [0x50,0x51,0x58,0x74,0x75,0x76,0x77])
                    run(m,'FireHit')
                    assert m.ram[0x392]==96 and m.ram[0x391]==96,'fire hit damaged Mario'
                    current=bytes(m.ram[a]for a in [0x50,0x51,0x58,0x74,0x75,0x76,0x77])
                    if m.ram[5]==1:
                        assert current[0]==0xc1 and current[1:]==preserved[1:],'KO must hand Mario to the native opponent-down script'
                    else:assert current==preserved,'fire interrupted native defense/punch animation'
                    if defense>=4:
                        assert m.ram[0x398]==hp and m.ram[5]==0 and m.ram[0x6024]==0
                    else:
                        ref=Memory(BASE);combat_fixture(ref,hp,defense,kind)
                        ref.ram[0x74]=kind;ref.ram[0x75]=4;ref.ram[0x58]=0x80;ref.ram[0xb5]=ref.ram[0x76]=ref.ram[0x77]=0
                        run(ref,0x81b2)
                        for a in [5,0x90,0x91,0xbb,0x391,0x398,0x3d2,0x3e0,0x3e3,0x3e5,0x3e6,0x4a,0x4b,0x4c]:
                            assert m.ram[a]==ref.ram[a],(hp,defense,kind,hex(a),m.ram[a],ref.ram[a])
                        assert m.ram[0x6024]==1 and m.ram[0x398]==max(0,hp-4+defense)
                        if hp<=4-defense:assert m.ram[5]==1,'must enter native knockdown, not HP-only defeat'
                    count+=1
    passed('Native combat oracle: defenses, both heights, self-damage prevention, stars, score and knockdowns',count)
    count=0
    for key,value in [(4,0),(0x1c,1),(5,1),(5,2),(0x50,0),(0x50,0x40),(0x392,0),(0x399,0),(0xbb,0x80)]:
        m=initialized();combat_fixture(m);m.ram[4]=0xff;m.ram[0x50]=1;m.ram[0xd0]=0x40;m.ram[key]=value
        run(m,'FireUpdate');assert m.ram[0x6010]==0 and m.ram[0x6011]==0;count+=1
    passed('No shots during intros, transitions, either knockdown, defeat or engine-disabled states',count)
    m=initialized();combat_fixture(m);m.ram[4]=0xff;m.ram[0x50]=1;m.ram[0xd0]=0x48;m.ram[0x15]=0xb0;m.ram[0xb0]=128;m.ram[0xb1]=180
    run(m,'FireUpdate');assert m.ram[0x6010]>0 and m.ram[0x6016]==1
    for i in range(20):run(m,'FireUpdate')
    assert m.ram[0x6025]==1,'held B must not repeatedly spawn'
    m.ram[0xd0]=0;run(m,'FireUpdate');m.ram[0xd0]=0x40;run(m,'FireUpdate');assert m.ram[0x6025]==2
    for i in range(80):m.ram[0xd0]=0;run(m,'FireUpdate')
    assert m.ram[0x6010]==m.ram[0x6011]==0,'shots must expire without wrapping'
    passed('Input edges, head/body selection, bounded two-shot pool and lifetime',103)
    # A full native palette upload must leave the CPU buffers untouched.
    for level in (0x20,0x10,0x00,0x8f):
        m=initialized();m.ram[4]=255;m.ram[0x480:0x4a0]=bytes(range(32));m.ram[0x48d]=level;m.ram[0x48e]=0x8f
        before=bytes(m.ram[0x480:0x4a0]);run(m,'PaletteUpload');assert before==bytes(m.ram[0x480:0x4a0])
        for i in list(range(13))+list(range(16,32)):assert m.ppu[0x3f00+i]==before[i]
    passed('Palette composition preserves native buffers, other palettes and fade levels',4)
    output=dict(rom_sha256=sha(ROM),passed=True,checks=checks)
    (P/'build/instructions.json').write_text(json.dumps(output,indent=2)+'\n')
    print('PASS',sum(c['cases']for c in checks),'assembled instruction cases')
    return output
if __name__=='__main__':check()
