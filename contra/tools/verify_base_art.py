"""Check supplied back-view pixels, view transitions and cached base art."""
import sys
from verify_sprites import ROOT,H,N,rom,MPU,run,pixels,fixture
sys.path.insert(0,str(ROOT.parent/'tools'))
from directional_art import pose as source_pose,source_info

back=(ROOT/'build/base-back-frames.chr').read_bytes()
front=(ROOT/'build/mario-frames.chr').read_bytes()
assert source_info()['sha256']=='ae395caae88ade3c2d6b3f2503c45e9f2b92ff5c84020d3f1891277a6bcf2a4d'
checks=0
for p in range(2):
    cpu=MPU();mem=cpu.memory
    mem[0x8000:0xc000]=rom[16+8*16384:16+9*16384]
    mem[0xc000:]=rom[16+15*16384:]
    mem[0x6900:0x7680]=back
    for index in range(27):
        if index in [22,25]:continue
        fixture(cpu,p,index);b=0x6000+p*128
        small=index in range(12,24)or index==26
        state='idle';step=0
        if index in [0,1,2,12,13,14]:state='walk';step=index%12
        elif index in [3,15]:state='skid'
        elif index in [4,16]:state='jump'
        elif index in range(5,10)or index in range(17,22):state='swim';step=index-(17 if small else 5)
        elif index in [10,26]:state='crouch'
        elif index==11:state='throw'
        art=source_pose('small'if small else'big','back',state,step)
        if small:art=[[0]*16 for _ in range(16)]+art
        expected={(x,y):value for y,row in enumerate(art)for x,value in enumerate(row)if value}
        for recoil in [0,1,0]:
            mem[N['PLAYER_RECOIL_TIMER']+p]=15 if recoil else 0
            for base in [True,False,True]:
                mem[N['LEVEL_LOCATION_TYPE']]=int(base)
                run(cpu,f'P{p}Render')
                raw=mem[b+0x1f]
                assert raw==index|(64 if recoil else 0)|(128 if base else 0)
                body=bytes(mem[0x6200+p*128:0x6280+p*128])
                assert body==front[raw*128:raw*128+128],'View changes must replace cached body art, including recoil'
                if base:assert pixels(body)==expected,('source rear pixels',p,index,recoil)
                checks+=1
print('PASS',checks,'base-view source pixel/recoil/transition checks, both sizes and players')
