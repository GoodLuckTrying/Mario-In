"""Native Mac background replacement. Opponent sprite banks and referee art stay intact."""
from pathlib import Path
from PIL import Image, ImageDraw
import sys,json
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from directional_art import pose,source_info
from analyze_art import frame,tile
def pixels(view='back',state='idle',step=0,boxing='guard',flip=False):
    if boxing=='guard':view='back_right'
    if boxing in ('left','right','highleft','highright','upper'):
        view='back_right';state='jump'if boxing in ('highleft','highright','upper')else'throw'
        flip=boxing in ('right','highright')
    src=pose('big',view,state,step)
    if boxing=='guard':
        # Reuse the supplied rear-diagonal raised arm, keeping the standing
        # legs planted. The unmodified idle cell leaves both arms at his hips.
        raised=pose('big',view,'throw')
        src=raised[2:26]+src[24:]
    elif boxing in ('left','right','highleft','highright','upper'):
        # Boxing punches retain planted feet. The source throwing/jumping
        # cells tuck up the legs, which made every punch resemble a leap.
        src=src[:24]+pose('big',view,'idle')[24:]
    elif boxing=='recoil':
        src=pose('big','back_right','skid')[:24]+pose('big','back_right','idle')[24:]
    im=Image.new('P',(16,32));im.putdata([v for row in src for v in row])
    if boxing=='fall':im=im.rotate(90,expand=True)
    if flip:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    # SMB1 Fire Mario: cap/shirt white, hair/shoes red, skin orange.
    # Swapping the red/brown roles made the back of his head a white blob.
    im.putdata([{0:0,1:1,2:3,3:2}[v]for v in im.getdata()])
    return im
def choose(n):
    if n in range(0x40,0x44):return None,'clear'
    if n==0x3a:return pixels('back',boxing='fall'),'down'
    if n in range(0x36,0x40):return pixels('back',state='crouch',boxing='none'),'getup'
    if 0x2a<=n<=0x35:return pixels('back_right',boxing='recoil'),'hurt'
    if 0x44<=n<=0x54:return pixels('back',state='walk',step=n%3,boxing='none'),'walk'
    if 0x55<=n<=0x57:return pixels('front',state='jump',boxing='none'),'win'
    if n in [5,0x5d,0x60,0x61]:return pixels('back',state='crouch',boxing='none'),'duck'
    if n in [0x18,0x19,0x1a,0x1b,0x1c,0x20,0x21]:return pixels('back_right',boxing='upper'),'upper'
    if n in [0x10,0x11,0x12,0x13,0x14]:return pixels('back',boxing='highright'),'highright'
    if n in [0xa,0xb,0xc,0xd,0xe,0xf]:return pixels('back',boxing='highleft'),'highleft'
    if n in [8,9,0x1d,0x1e,0x1f,0x22,0x23]:return pixels('back',boxing='left'),'left'
    if n in [0x15,0x16,0x17,0x28,0x29,0x59,0x5a,0x5b,0x5c]:return pixels('back',boxing='right'),'right'
    if n in [6,7,0x24,0x25,0x26,0x27]:return pixels('back_right',boxing='guard'),'dodge'
    return pixels('back',boxing='guard'),'guard'
def encode_tile(im,x,y):
    return bytes(sum(((im.getpixel((x+xx,y+yy))>>plane)&1)<<(7-xx)for xx in range(8))for plane in range(2)for yy in range(8))
def build(rom):
    chrdata=bytearray(rom[16+0x20000:]);bank=bytearray(chrdata[8192:12288]);unique={bytes(16):0xff}
    # The referee is also a background actor, visible alongside Mac before a bout.
    # Both actors must coexist in one MMC2 FE bank. Include nested column/run
    # commands; a column advance can immediately introduce a repeated tile run.
    reserved={t for n in range(128,175)for a,t in frame(n)['writes']}
    for t in reserved:bank[t*16:t*16+16]=chrdata[4096+t*16:4096+t*16+16]
    pool=iter(t for t in range(0xfd)if t not in reserved)
    commands=[];info=[];sheet=Image.new('RGB',(10*80,10*112),(30,45,65));draw=ImageDraw.Draw(sheet)
    colors=[(30,45,65),(255,255,255),(218,28,28),(255,162,70)]
    for n in range(98):
        im,kind=choose(n)
        launch_x,launch_y=40,192
        # Native Mac commands include partial torso redraws and clipped entry
        # frames, not independent full-body bounding boxes. Their changing
        # extents must never become Mario's position. Native $15 scrolling
        # still performs the pixel-by-pixel horizontal dodge movement.
        canvas=im if im is not None else Image.new('P',(8,8))
        x=48-canvas.width//2;y=216-canvas.height
        start=0x2000+(y//8)*32+x//8
        if im is not None:
            high=kind in ('highleft','highright','upper')
            hand_x=(10 if kind=='highright'else 5)if high else(13 if kind=='right'else 2)
            launch_x=x+hand_x;launch_y=y+(2 if high else 14)
        occupied=[(x,y)for y in range(0,canvas.height,8)for x in range(0,canvas.width,8)if encode_tile(canvas,x,y)!=bytes(16)]
        if occupied:
            lx=min(x for x,y in occupied);ty=min(y for x,y in occupied)
            rx=max(x for x,y in occupied)+8;by=max(y for x,y in occupied)+8
        else:lx=ty=rx=by=0
        data=bytearray();tiles=[]
        for x in range(lx,rx,8):
            address=start+x//8+ty//8*32
            data.extend([address>>8,address&255,(by-ty)//8])
            for y in range(ty,by,8):
                b=encode_tile(canvas,x,y)
                if b not in unique:
                    idx=next(pool)
                    unique[b]=idx;bank[idx*16:idx*16+16]=b
                data.append(unique[b]);tiles.append([address+(y-ty)//8*32,unique[b]])
        data.append(0);commands.append(bytes(data));info.append(dict(id=n,pose=kind,tiles=tiles,origin=start,width=canvas.width,height=canvas.height,launch_x=launch_x,launch_y=launch_y))
        ox=n%10*80;oy=n//10*112;draw.text((ox,oy),f'{n:02X} {kind}',fill='white')
        for yy in range(canvas.height):
            for xx in range(canvas.width):
                v=canvas.getpixel((xx,yy))
                if v and ox+xx<sheet.width and oy+16+yy<sheet.height:sheet.putpixel((ox+xx,oy+16+yy),colors[v])
    # Four rolling fireball shapes, in this background bank only.
    fire=[]
    for phase in range(4):
        im=Image.new('P',(16,16));d=ImageDraw.Draw(im)
        d.ellipse((2,2,13,13),fill=2);d.ellipse((3,3,12,12),fill=3)
        d.ellipse((5,4,10,10),fill=1);d.line((9,7,12,9,10,12,6,11),fill=2,width=2)
        im=im.rotate(phase*90)
        for x,y in [(0,0),(0,8),(8,0),(8,8)]:
            b=encode_tile(im,x,y)
            if b not in unique:
                idx=next(pool);unique[b]=idx;bank[idx*16:idx*16+16]=b
            fire.append(unique[b])
    # Keep the hardware latch sentinels and common blank tile intact.
    assert bank[0xfd*16:]==chrdata[8192+0xfd*16:12288]
    chrdata[8192:12288]=bank
    blob=bytearray(196);cache={};ptrs=[]
    for i,data in enumerate(commands):
        if data not in cache:cache[data]=0x8011+len(blob);blob+=data
        addr=cache[data];blob[i*2:i*2+2]=addr.to_bytes(2,'little');ptrs.append(addr)
    assert len(blob)<=0xfef,len(blob)
    p=ROOT/'punchout';sheet.resize((800,1120),Image.Resampling.NEAREST).save(p/'build/mario-poses.png')
    (p/'build/art-map.json').write_text(json.dumps(dict(source=source_info(),tile_count=len(unique),fire_tiles=fire,frames=info),indent=2))
    # Reclaim only the original Mac half of the CHR0 portrait. The FE bank belongs
    # to the opposing portrait and must never be repointed here.
    portrait=Image.new('P',(32,64))
    portrait.paste(pixels('front',boxing='none').resize((24,48),Image.Resampling.NEAREST),(4,8))
    portrait.putdata([{0:0,1:2,2:3,3:1}[v]for v in portrait.getdata()])
    # CHR0 also supplies the referee through MMC2's FD latch, including the
    # same tile IDs as Mac's portrait. Keep it byte-identical and put the
    # portrait in the now-unused third Mac animation bank instead.
    atlas1=bytearray(chrdata[:4096])
    pool1=iter([0x4a,0x4b,0x4c,0x4d,0x4e,0x4f,0x50,0x53,0x54,0x55,0x58,0x59,0x5a,0x5f,0x60,0x61,0x62,0x67,0x68,0x69,0x6a,0x6b,0x71,0x72,0x73,0x74])
    unique1={bytes(16):0xff};portrait_tiles=[]
    for y in range(0,64,8):
        portrait_tiles.append(0xff)
        for x in range(0,32,8):
            b=encode_tile(portrait,x,y)
            if b not in unique1:
                t=next(pool1);unique1[b]=t;atlas1[t*16:t*16+16]=b
            portrait_tiles.append(unique1[b])
        portrait_tiles.append(0x63 if y<56 else 0x75)
    chrdata[3*4096:4*4096]=atlas1
    return chrdata,blob,fire,portrait_tiles,info
