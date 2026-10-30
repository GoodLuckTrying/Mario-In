"""Shared IPS encoding and SMB1 graphics extraction."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess

ROOT = Path(__file__).resolve().parents[1]
CC65 = ROOT / 'vendor/smb1base/tools/Windows/cc65/bin'
KI = Path('C:/nes/Kid Icarus (USA, Europe).nes')
SMB = Path('C:/nes/Super Mario Bros. (World).nes')
HASHES = ['931786d6920dea7f9e183d907d3c4cff123197fcd14ae4066f1e817df32fd02f',
          '0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea']

def ips(old, new):
    out=bytearray(b'PATCH');i=0
    while i<len(new):
        if i<len(old) and old[i]==new[i]: i+=1;continue
        start=i;i+=1
        while i<len(new) and i-start<65535:
            if i<len(old) and old[i]==new[i] and new[i:i+8]==old[i:i+8]:break
            i+=1
        out+=start.to_bytes(3,'big')+(i-start).to_bytes(2,'big')+new[start:i]
    return out+b'EOF'

def graphics(smb, output_dir=None):
    output_dir = output_dir or ROOT/'build'
    output_dir.mkdir(parents=True, exist_ok=True)
    chr=smb[0x8010:]
    # Original SMB1 PlayerGraphicsTable, in its original row order.
    frames=[list(range(i,i+8)) for i in (0,8,16,24,32)]
    frames += [[8,9,40,41,42,43,44,45],[8,9,10,11,12,48,44,45],
               [8,9,10,11,46,47,44,45],[8,9,40,41,42,43,92,93],
               [8,9,10,11,12,13,94,95],[252,252,8,9,88,89,90,90],
               [8,9,40,41,42,43,14,15]]
    frames += [[252]*4+x for x in [[50,51,52,53],[54,55,56,57],
        [58,55,59,60],[61,62,63,64],[50,65,66,67],
        [50,51,68,69],[50,51,68,71],[50,51,72,73],
        [50,51,144,145],[58,55,146,147],[158,158,159,159],
        [58,55,79,79]]]
    frames += [[0,1,76,77,74,74,75,75]]
    frames += [[252,252,0,1,76,77,78,78]]
    packed=bytearray()
    for n,frame in enumerate(frames):
        for index,tile in enumerate(frame):
            data=chr[tile*16:tile*16+16]
            # SMB mirrors the right half of repeated standing/duck/death tiles.
            if (n==10 and index==7) or (n==22 and index in (5,7)) or (n==23 and index==7) or (n==24 and index in (5,7)) or (n==25 and index==7):
                data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
            packed+=data
    (output_dir/'mario-frames.chr').write_bytes(packed)
    assets=[]
    # SMB mushroom, flower, star, green mushroom, then rotating fireballs.
    for kind,tiles in enumerate([(0x76,0x77,0x78,0x79),(0xD6,0xD6,0xD9,0xD9),
                  (0x8D,0x8D,0xE4,0xE4),(0x76,0x77,0x78,0x79),
                  (0x64,0x65,0x64,0x65)]):
        for index,t in enumerate(tiles):
            data=chr[t*16:t*16+16]
            if kind in (1,2) and index%2:data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
            assets+=data
    for index,tile in enumerate((0x3A,0x37,0x4F,0x4F)):
        data=chr[tile*16:tile*16+16]
        if index==3:data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
        assets+=data
    (output_dir/'items.chr').write_bytes(bytes(assets))
