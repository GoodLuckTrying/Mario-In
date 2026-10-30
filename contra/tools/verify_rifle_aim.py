"""Check assembled rifle orientation/attachment against native aim semantics."""
import math
from PIL import ImageDraw
from verify_sprites import ROOT,H,N,rom,MPU,run,pixels,fixture,reference,Image

angles=(ROOT/'build/angle-rifles.chr').read_bytes()
horizontal=(ROOT/'build/rifles.chr').read_bytes()
chr_data=bytearray(4096)
chr_data[0x680:0x800]=horizontal
chr_data[0x420:0x520]=angles[:256]
chr_data[0x800:0x900]=angles[256:]
native_modes=[3,1,0,2,0,0,2,0,1,3,4,4]
count=0
preview=Image.new('RGB',(8*40,6*48),(48,56,80))
colors=[None,(185,187,179),(78,80,72),(0,0,0)]

for p in range(2):
    cpu=MPU();mem=cpu.memory
    mem[0x8000:0xc000]=rom[16+8*16384:16+9*16384]
    mem[0xc000:]=rom[16+15*16384:]
    for pose in range(27):
        if pose in [22,25]:continue
        fixture(cpu,p,pose);b=0x6000+p*128
        for recoil in range(2):
            mem[N['PLAYER_RECOIL_TIMER']+p]=15 if recoil else 0
            run(cpu,f'P{p}Render');raw=mem[b+0x1f]
            ref=reference(pose,recoil,False)
            gun={(x,y):v for(x,y),(layer,v)in ref.items()if layer=='gun'}
            gx=min(x for x,y in gun);gy=min(y for x,y in gun)
            style=(0 if pose<12 or pose==24 else 4 if 17<=pose<=21 else 2)+recoil
            for left in [False,True]:
                origin=80,50;o=0x6410+p*16
                for i in range(4):mem[o+i*4:o+i*4+4]=[50+(i//2)*16,0,0x20|(64 if left else 0),80+(8 if left else 0)]
                for aim in range(12):
                    for airborne in [False,True]:
                        mem[N['PLAYER_AIM_DIR']+p]=aim
                        mem[N['PLAYER_JUMP_STATUS']+p]=int(airborne)
                        mode=4 if aim in [4,5]and airborne else native_modes[aim]
                        run(cpu,'MakeGun',raw,p)
                        actual=mem[0x61e0:0x61e8]
                        dx=gx;dy=gy
                        tile=0x68+style*4;second=tile+2
                        if mode:
                            dy += {1:-6,2:-5,3:-7,4:-4}[mode]
                            if mode<3:
                                dx-=3 if style>=2 else 0
                                tile=[0x42,0x46,0x4a,0x4e,0x80,0x84][style];second=tile+2
                            else:
                                dx+=9 if style<2 else 3
                                tile=0x88+(style//2)*2;second=0x8e
                        flags=0x23|(64 if left else 0)|(128 if mode in [2,4]else 0)
                        x=origin[0]+(8-dx if left else dx);y=origin[1]+dy
                        expected=[y,tile,flags,x,y,second,flags,x+(-8 if left else 8)]
                        assert actual==expected,(p,pose,recoil,left,aim,airborne,actual,expected)
                        decoded={}
                        for j in range(2):
                            sy,t,attr,sx=actual[j*4:j*4+4]
                            for(xx,yy),v in pixels(chr_data[t*16:t*16+32],8,16).items():
                                position=(sx-origin[0]+(7-xx if left else xx),sy-origin[1]+(15-yy if flags&128 else yy))
                                decoded[position]=v
                        source=gun
                        if mode>=3 and recoil:
                            ready=reference(pose,False,False)
                            source={(x-1,y):v for(x,y),(layer,v)in ready.items()if layer=='gun'}
                        normalized={(xx-gx,yy-gy):v for(xx,yy),v in source.items()}
                        expected_pixels={}
                        pivot=6 if style<2 else 3
                        width=16 if mode<3 else 8
                        for yy in range(16):
                            for xx in range(width):
                                if mode in [1,2]:
                                    c=math.sqrt(.5);sx=round((xx-6)*c-(yy-8)*c+pivot);sy=round((xx-6)*c+(yy-8)*c+2)
                                elif mode>=3:sx=pivot-(yy-9);sy=2+(xx-3)
                                else:sx=xx;sy=yy
                                value=normalized.get((sx,sy))
                                if value:
                                    px=dx+xx;py=dy+(15-yy if mode in [2,4]else yy)
                                    if left:px=15-px
                                    expected_pixels[px,py]=value
                        assert decoded==expected_pixels,('angled source pixels',p,pose,recoil,left,aim,airborne)
                        if p==0 and pose in [23,24,17]and airborne and aim in [7,8,9,0,1,2,3,4]and not left:
                            row={23:0,24:2,17:4}[pose]+recoil;col=[7,8,9,0,1,2,3,4].index(aim)
                            body=bytes(mem[0x6200:0x6280])
                            body_colors=[None,(181,49,32),(234,158,34),(107,109,0)]
                            for(xx,yy),v in decoded.items():preview.putpixel((col*40+12+xx,row*48+8+yy),colors[v])
                            for(xx,yy),v in pixels(body).items():preview.putpixel((col*40+12+xx,row*48+8+yy),body_colors[v])
                        count+=1
preview.resize((960,864),Image.Resampling.NEAREST).save(ROOT/'build/rifle-aim-preview.png')
print('PASS',count,'assembled aim checks: all poses, native aim codes, grounded/airborne, both players/facings, recoil and source pixels')
