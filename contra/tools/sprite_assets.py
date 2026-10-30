"""Convert the user's rifle sheet to exact body/gun NES layers and recoil deltas."""
from pathlib import Path
import hashlib,json,math
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
COUNT=27
BODY={(181,49,32):1,(234,158,34):2,(107,109,0):3}
GUN={(0,0,0):3,(78,80,72):2,(185,187,179):1}
EMPTY={(0,41,140),(146,144,255),(201,200,255)}
BIG_X=[23,47,69,91,115,139,163,187,211,233]
SMALL_X=[63,83,101,119,139,159,179,199]
BIG={0:3,1:1,2:2,3:6,4:4,5:8,6:9,7:8,8:9,9:8,10:5,11:7,24:0}
SMALL={12:3,13:1,14:2,15:4,16:5,22:7,23:0,26:6}


def encode(pixels,width=16,height=32):
    """8x16 sprite pairs, left/right columns within each 16-pixel row."""
    out=bytearray()
    for y0 in range(0,height,16):
        for x0 in range(0,width,8):
            for half in (0,8):
                for bit in (0,1):
                    for y in range(8):
                        out.append(sum(((pixels[y0+half+y][x0+x]>>bit)&1)<<(7-x)for x in range(8)))
    return bytes(out)


def body_under_rifle(fallback,pose,x,y):
    """The sheet's rifle obscures Mario; recover only those pixels from SMB1.

    Small crouching is custom art, so use the small standing torso beneath
    its gun. All visible supplied body pixels remain untouched.
    """
    frame=fallback[(23 if pose==26 else pose)*128:][:128]
    offset=(y//16*4+x//8*2+(y%16)//8)*16
    return ((frame[offset+y%8]>>(7-x%8))&1)|(((frame[offset+8+y%8]>>(7-x%8))&1)<<1)


def player_only_gun_tiles(original,symbols):
    """Parse every native metasprite, including shared tails and single records."""
    bank=original[16+16384:16+2*16384]
    players=set(range(2,0x1e))|set(range(0x50,0x59))
    owners={}
    for sprite in list(range(1,128))+list(range(128,208)):
        table=symbols['sprite_ptr_tbl_0'if sprite<128 else'sprite_ptr_tbl_1']
        index=sprite-1 if sprite<128 else sprite-128
        pointer=table-0x8000+index*2
        pc=int.from_bytes(bank[pointer:pointer+2],'little')-0x8000
        count=bank[pc];pc+=1
        if count>=128:
            tiles=[bank[pc]]
        else:
            tiles=[]
            for _ in range(count):
                for guard in range(10):
                    if bank[pc]!=0x80:break
                    pc=int.from_bytes(bank[pc+1:pc+3],'little')-0x8000
                else:raise AssertionError('Native shared-sprite tail cycle')
                tiles.append(bank[pc+1]);pc+=4
        for tile in tiles:
            for address in [((tile&1)*256)+(tile&0xfe),((tile&1)*256)+(tile&0xfe)+1]:
                owners.setdefault(address,set()).add(sprite)
    reserved=set(range(0x68,0x80))|set(range(0x42,0x52))|set(range(0x80,0x90))
    assert all(owners[tile]and owners[tile]<=players for tile in reserved),'Rifle tiles must be original-player-only'
    return {f'{tile:02X}':sorted(owners[tile])for tile in sorted(reserved)}


def angled_rifles(shapes):
    """Nearest-pixel CHR rotation about the grip; no new palette or OAM slots."""
    decoded=[]
    for data in shapes:
        pixels=[]
        for y in range(16):
            row=[]
            for x in range(16):
                offset=(x//8)*32+(y//8)*16
                row.append(((data[offset+y%8]>>(7-x%8))&1)|(((data[offset+8+y%8]>>(7-x%8))&1)<<1))
            pixels.append(row)
        decoded.append(pixels)
    result=bytearray();c=math.sqrt(.5)
    for index,source in enumerate(decoded):
        pivot_x=6 if index<2 else 3
        output=[[0]*16 for _ in range(16)]
        for y in range(16):
            for x in range(16):
                sx=round((x-6)*c-(y-8)*c+pivot_x)
                sy=round((x-6)*c+(y-8)*c+2)
                if 0<=sx<16 and 0<=sy<16:output[y][x]=source[sy][sx]
        result+=encode(output,height=16)
    # Vertical barrels fit one 8x16 sprite. Recoil keeps its body/grip offset.
    for index in (0,2,4):
        source=decoded[index];pivot_x=6 if index==0 else 3
        output=[[0]*8 for _ in range(16)]
        for y in range(16):
            for x in range(8):
                sx=pivot_x-(y-9);sy=2+(x-3)
                if 0<=sx<16 and 0<=sy<16:output[y][x]=source[sy][sx]
        result+=encode(output,width=8,height=16)
    result+=bytes(32) # shared transparent second half of a vertical rifle
    assert len(result)==512
    return bytes(result)


def build(fallback,original,symbols):
    path=ROOT/'assets/mario-rifle-sheet.png'
    image=Image.open(path).convert('RGB')
    assert image.size==(258,242),'Unexpected sprite-sheet dimensions'
    body_frames=[[],[]];gun_shapes=[];metadata=[];rects=[]
    for pose in range(COUNT):
        variants=[];gun_meta=[]
        for recoil in (0,1):
            if pose in BIG:
                x=BIG_X[BIG[pose]];y=133+36*recoil;height=32
            elif pose in SMALL:
                x=SMALL_X[SMALL[pose]];y=5+20*recoil;height=16
            elif 17<=pose<=21:
                x=[115,139][(pose-17)%2];y=69+20*recoil;height=16
            else:
                variants.append(fallback[pose*128:(pose+1)*128]);gun_meta.append(None)
                continue
            width=20 if height==32 or 17<=pose<=21 else 16
            pixels=[[0]*16 for _ in range(32)];gun={}
            for dy in range(height):
                for dx in range(width):
                    color=image.getpixel((x+dx,y+dy))
                    if color in EMPTY:continue
                    if color in GUN:
                        gun[dx,32-height+dy]=GUN[color]
                        if dx<16:
                            pixels[32-height+dy][dx]=body_under_rifle(fallback,pose,dx,32-height+dy)
                        continue
                    if pose==11:
                        assert color in [(250,222,185),(234,158,34),(181,49,32)]
                        value={(250,222,185):1,(234,158,34):2,(181,49,32):3}[color]
                    else:
                        assert color in BODY,(pose,recoil,dx,dy,color)
                        value=BODY[color]
                    assert dx<16,'Body pixels must fit the existing player tiles'
                    pixels[32-height+dy][dx]=value
            variants.append(encode(pixels))
            if gun:
                gx=min(v[0]for v in gun);gy=min(v[1]for v in gun)
                shape=[[0]*16 for _ in range(16)]
                for(dx,dy),value in gun.items():
                    assert dx-gx<16 and dy-gy<16
                    shape[dy-gy][dx-gx]=value
                encoded=encode(shape,height=16)
                if encoded not in gun_shapes:gun_shapes.append(encoded)
                gun_meta.append({'x':gx,'y':gy,'tile':0x68+4*gun_shapes.index(encoded)})
            else:gun_meta.append(None)
            rects.append({'pose':pose,'recoil':bool(recoil),'x':x,'y':y,'width':width,'height':height})
        assert len(variants)==2
        for index in (0,1):body_frames[index].append(variants[index])
        if gun_meta[0]:
            a,b=gun_meta
            assert b['x']==a['x']-1 and b['y']==a['y'] and b['tile']==a['tile']+4
        else:assert gun_meta[1]is None
        metadata.append(gun_meta[0])
    assert len(gun_shapes)==6
    # A compact XOR delta avoids larger per-frame VRAM transfers or a new ROM bank.
    delta=bytearray();offsets=[]
    for ready,recoil in zip(*body_frames):
        offsets.append(len(delta))
        for index,(a,b)in enumerate(zip(ready,recoil)):
            if a!=b:delta.extend([index,a^b])
        delta.append(0xff)
    out=ROOT/'build'
    (out/'mario-base-frames.chr').write_bytes(b''.join(body_frames[0]))
    (out/'mario-recoil.bin').write_bytes(delta)
    # Expanded expected frames for hardware checks indexed by the raw pose key.
    expanded=b''.join(body_frames[0])+bytes((64-COUNT)*128)+b''.join(body_frames[1])
    (out/'mario-frames.chr').write_bytes(expanded)
    (out/'rifles.chr').write_bytes(b''.join(gun_shapes))
    (out/'angle-rifles.chr').write_bytes(angled_rifles(gun_shapes))
    from directional_art import pose as directional_pose,source_info
    back_frames=[]
    for index in range(COUNT):
        if index in [22,25]:
            back_frames.append(body_frames[0][index]);continue
        small=index in range(12,24)or index==26
        state='idle';step=0
        if index in [0,1,2,12,13,14]:state='walk';step=index%12
        elif index in [3,15]:state='skid'
        elif index in [4,16]:state='jump'
        elif index in range(5,10)or index in range(17,22):state='swim';step=index-(17 if small else 5)
        elif index in [10,26]:state='crouch'
        elif index==11:state='throw'
        art=directional_pose('small'if small else'big','back',state,step)
        if small:art=[[0]*16 for _ in range(16)]+art
        back_frames.append(encode(art))
    (out/'base-back-frames.chr').write_bytes(b''.join(back_frames))
    expanded=bytearray(expanded+bytes(256*128-len(expanded)))
    for index,art in enumerate(back_frames):
        for recoil in [0,64]:expanded[(128+recoil+index)*128:(129+recoil+index)*128]=art
    (out/'mario-frames.chr').write_bytes(expanded)
    lines=[f'MARIO_POSE_COUNT={COUNT}',
           'RecoilPatchLo: .byte '+','.join(f'<(RecoilPatches+{n})'for n in offsets),
           'RecoilPatchHi: .byte '+','.join(f'>(RecoilPatches+{n})'for n in offsets)]
    for label,key,empty in [('RifleX','x',0),('RifleY','y',0),('RifleTile','tile',255)]:
        values=[m[key]if m else empty for m in metadata]+[empty]*(64-COUNT)
        values += [(m[key]+(-1 if key=='x' else 4 if key=='tile' else 0))if m else empty for m in metadata]
        lines.append(label+': .byte '+','.join(map(str,values)))
    lines.extend(['AngleDiagTile: .byte $42,$46,$4A,$4E,$80,$84',
                  'AngleVerticalTile: .byte $88,$88,$8A,$8A,$8C,$8C',
                  'AngleDiagDX: .byte 0,0,253,253,253,253',
                  'AngleVerticalDX: .byte 9,9,3,3,3,3',
                  'AimMode: .byte 3,1,0,2,5,5,2,0,1,3,4,4',
                  'AimYAdjust: .byte 0,250,251,249,252',
                  'AimFlip: .byte 0,0,$80,0,$80'])
    (out/'sprite-data.inc').write_text('\n'.join(lines)+'\n')
    result={'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'pose_count':COUNT,
            'body_under_rifle':'Restore occluded SMB1 body pixels; rifle OAM precedes the complete body',
            'recoil_flag':64,'rifle_chr_address':0x680,'recoil_bytes':len(delta),
            'angled_rifle_chr_blocks':[{'address':0x420,'offset':0,'size':256},{'address':0x800,'offset':256,'size':256}],
            'angled_rifle_rom_bank':9,
            'directional_source':source_info(),'base_back_view_flag':128,'base_back_frames_wram':0x6900,
            'source_rectangles':rects,'rifles':metadata,
            'native_tile_owners':player_only_gun_tiles(original,symbols),
            'palette_policy':'Preserve native enemies; use stage sprite palette 3'}
    (out/'sprite-manifest.json').write_text(json.dumps(result,indent=2))
    return result
