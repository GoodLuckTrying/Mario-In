"""Execute the renderer and reconstruct its pixels against the supplied PNG."""
from pathlib import Path
import hashlib,json
from PIL import Image
from py65.devices.mpu6502 import MPU

ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'build/manifest.json').read_text())
H,N=manifest['labels'],manifest['native']
rom=(ROOT/'dist/Mario and Luigi in Contra.nes').read_bytes()
sheet=Image.open(ROOT/'assets/mario-rifle-sheet.png').convert('RGB')
assert hashlib.sha256((ROOT/'assets/mario-rifle-sheet.png').read_bytes()).hexdigest()=='5bfefdc72aefbedc38313276466c08311ac3e1a3b04a0b3bb89843f74d14cd79'
expected=(ROOT/'build/mario-frames.chr').read_bytes()
rifles=(ROOT/'build/rifles.chr').read_bytes()
body_colors={(181,49,32):1,(234,158,34):2,(107,109,0):3}
gun_colors={(0,0,0):3,(78,80,72):2,(185,187,179):1}
background={(0,41,140),(146,144,255),(201,200,255)}
big_x=[23,47,69,91,115,139,163,187,211,233]
small_x=[63,83,101,119,139,159,179,199]
big={0:3,1:1,2:2,3:6,4:4,5:8,6:9,7:8,8:9,9:8,10:5,11:7,24:0}
small={12:3,13:1,14:2,15:4,16:5,22:7,23:0,26:6}
# Independent clean-body oracle: SMB1's original row-major tile table.
smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()[0x8010:]
clean=[list(range(i,i+8))for i in (0,8,16,24,32)]
clean += [[8,9,40,41,42,43,44,45],[8,9,10,11,12,48,44,45],
 [8,9,10,11,46,47,44,45],[8,9,40,41,42,43,92,93],
 [8,9,10,11,12,13,94,95],[252,252,8,9,88,89,90,90],
 [8,9,40,41,42,43,14,15]]
clean += [[252]*4+x for x in [[50,51,52,53],[54,55,56,57],[58,55,59,60],
 [61,62,63,64],[50,65,66,67],[50,51,68,69],[50,51,68,71],
 [50,51,72,73],[50,51,144,145],[58,55,146,147],[158,158,159,159],
 [58,55,79,79]]]
clean += [[0,1,76,77,74,74,75,75],[252,252,0,1,76,77,78,78]]
def clean_pixel(pose,x,y):
    pose=23 if pose==26 else pose
    index=y//8*2+x//8;tile=clean[pose][index];px=x%8
    if (pose==10 and index==7)or(pose in [22,24]and index in [5,7])or(pose in [23,25]and index==7):px=7-px
    data=smb[tile*16:tile*16+16]
    return ((data[y%8]>>(7-px))&1)|(((data[8+y%8]>>(7-px))&1)<<1)

def run(cpu,label,a=0,x=0):
    cpu.pc=H[label];cpu.a=a;cpu.x=x;cpu.sp=0xfd;cpu.p=0x20
    cpu.memory[0x1fe:0x200]=[0xff,0x7f]
    for _ in range(6000):
        cpu.step()
        if cpu.pc==0x8000:return
    raise AssertionError((label,hex(cpu.pc)))

def pixels(data,width=16,height=32):
    result={}
    for row in range(height//16):
        for col in range(width//8):
            for half in range(2):
                tile=data[(row*(width//8)*2+col*2+half)*16:][:16]
                for y in range(8):
                    for x in range(8):
                        value=((tile[y]>>(7-x))&1)|(((tile[8+y]>>(7-x))&1)<<1)
                        if value:result[col*8+x,row*16+half*8+y]=value
    return result

def fixture(cpu,p,pose):
    mem=cpu.memory;b=0x6000+p*128
    mem[b:b+128]=[0]*128
    for key in ['PLAYER_STATE','INDOOR_PLAYER_ADV_FLAG','INDOOR_PLAYER_JUMP_FLAG','PLAYER_JUMP_STATUS','PLAYER_RECOIL_TIMER']:
        mem[N[key]+p]=0
    mem[N['PLAYER_STATE']+p]=1
    mem[N['BOSS_DEFEATED_FLAG']]=0
    mem[b]=0x4d;mem[b+0x20]=0xff
    mem[b+4]=int(pose<12 or pose in [24,25])
    mem[b+0xc]=1;mem[b+0x12]=1;mem[b+0x28]=10
    if pose in [0,1,2,12,13,14]:mem[b+6]=1;mem[b+0x29]=pose%12
    if pose in [3,15]:mem[b+6]=1;mem[b+0xc]=2
    if pose in [4,16]:mem[b+5]=1
    if pose in range(5,10) or pose in range(17,22):
        mem[b+0x47]=1;mem[b+0x29]=pose-(5 if pose<12 else 17)
    if pose==10:mem[b+0x1d]=1
    if pose==11:mem[b+0x2d]=8
    if pose==22:mem[N['PLAYER_STATE']+p]=2
    if pose==25:mem[b+0x35]=36
    if pose==26:mem[b+2]=4

def reference(pose,recoil,left):
    if pose in big:x,y,h=big_x[big[pose]],133+36*recoil,32
    elif pose in small:x,y,h=small_x[small[pose]],5+20*recoil,16
    elif 17<=pose<=21:x,y,h=[115,139][(pose-17)%2],69+20*recoil,16
    else:return None
    width=20 if h==32 or 17<=pose<=21 else 16
    result={}
    for dy in range(h):
        for dx in range(width):
            color=sheet.getpixel((x+dx,y+dy))
            if color in background:continue
            if color in gun_colors:token=('gun',gun_colors[color])
            elif pose==11:token=('body',{(250,222,185):1,(234,158,34):2,(181,49,32):3}[color])
            else:token=('body',body_colors[color])
            result[15-dx if left else dx,32-h+dy]=token
    return result

checks=0
for p in range(2):
    cpu=MPU();mem=cpu.memory
    mem[0x8000:0xc000]=rom[16+8*16384:16+9*16384]
    mem[0xc000:]=rom[16+15*16384:]
    for pose in range(27):
        fixture(cpu,p,pose);b=0x6000+p*128
        for recoil in [0,1,0,1]:
            mem[N['PLAYER_RECOIL_TIMER']+p]=15 if recoil else 0
            run(cpu,f'P{p}Render')
            raw=mem[b+0x1f]
            assert raw==(pose|(64 if recoil and pose not in [22,25] else 0)),(p,pose,recoil,raw)
            body=bytes(mem[0x6200+p*128:0x6280+p*128])
            assert body==expected[raw*128:raw*128+128],('rendered body',p,pose,recoil)
            source=reference(pose,recoil,False)
            if source is not None:
                actual=pixels(body)
                for (x,y),(layer,value) in source.items():
                    if x>=16:continue
                    target=value if layer=='body' else clean_pixel(pose,x,y)
                    assert actual.get((x,y),0)==target,('complete body under angled rifle',p,pose,recoil,x,y)
            for left in [False,True]:
                mem[N['PLAYER_AIM_DIR']+p]=7 if left else 2
                origin=80,50;o=0x6410+p*16
                for i in range(4):
                    mem[o+i*4:o+i*4+4]=[50+(i//2)*16,0,64 if left else 0,80+(8 if left else 0)]
                run(cpu,'MakeGun',raw,p)
                composed={(15-x if left else x,y):('body',v)for(x,y),v in pixels(body).items()}
                for slot in range(2):
                    sy,tile,attr,sx=mem[0x61e0+slot*4:0x61e4+slot*4]
                    if sy==0xf8:continue
                    assert attr==(3|(64 if left else 0)),'Rifles must use native palette 3'
                    assert 0x68<=tile<=0x7e and tile%2==0
                    for(x,y),value in pixels(rifles[(tile-0x68)*16:][:32],8,16).items():
                        xy=sx-origin[0]+(7-x if left else x),sy-origin[1]+y
                        composed[xy]=('gun',value)
                ref=reference(pose,recoil,left)
                if ref is not None:assert composed==ref,('source pixels',p,pose,recoil,left,set(composed.items())^set(ref.items()))
                for i in range(4):mem[o+i*4]=0xf8
                run(cpu,'MakeGun',raw,p)
                assert mem[0x61e0]==mem[0x61e4]==0xf8,'Hidden players must hide the complete gun'
                checks+=1
print('PASS',checks,'source-pixel checks: both players/facings, every pose, recoil toggles, palette separation and hidden sprites')
