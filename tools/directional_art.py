"""Exact supplied directional cells, shared across the native NES ports."""
from pathlib import Path
import hashlib
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/mario-directional-sheet.png'
VIEWS={'front':0,'front_right':1,'right':2,'back_right':3,'back':4}
ROLES={(223,0,0):1,(255,151,54):2,(136,120,9):3}

def source_info():
    return {'file':str(SOURCE),'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            'permission':'User supplied with stated permission, 23 October 2026',
            'credit':'Artist name not supplied'}

def rectangle(size,view,state='idle',step=0):
    direction=VIEWS[view]
    if size=='small':
        row={'idle':0,'walk':1+step%3,'jump':4,'crouch':5,'skid':0,'throw':6,'swim':1+step%3}[state]
        return 86+direction*17,1+row*17,16,16
    assert size=='big'
    if state in ['walk','swim']:
        row=step%3 if state=='walk'else 3+step%4
        return 426+direction*17,1+row*33,16,32
    row={'idle':0,'crouch':1,'jump':2,'skid':3,'throw':4}[state]
    return 341+direction*17,1+row*33,16,32

def pose(size,view,state='idle',step=0):
    im=Image.open(SOURCE).convert('RGBA')
    assert im.size==(597,265)
    x,y,width,height=rectangle(size,view,state,step)
    output=[]
    for dy in range(height):
        row=[]
        for dx in range(width):
            color=im.getpixel((x+dx,y+dy))
            if color[3]==0 or color[:3]==(0,41,140):row.append(0)
            else:
                assert color[:3]in ROLES,(size,view,state,step,dx,dy,color)
                row.append(ROLES[color[:3]])
        output.append(row)
    return output
