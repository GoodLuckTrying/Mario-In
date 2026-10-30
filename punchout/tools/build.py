from pathlib import Path
import sys,json,struct
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import sha,ips,assemble,install
from build_reference import build as reference,BASE
from art import build as art
P=ROOT/'punchout';NAME="Mario in Mike Tyson's Punch-Out!!"
def build():
    base,ref=reference();rom=bytearray(base);changes=[]
    def put(bank,addr,data,name,expected=None):
        origin=0x8000 if bank<13 else 0xa000+(bank-13)*0x2000
        offset=16+bank*0x2000+addr-origin
        if expected is not None:assert rom[offset:offset+len(expected)]==expected,(name,hex(addr))
        rom[offset:offset+len(data)]=data;changes.append(dict(bank=bank,cpu=addr,size=len(data),name=name))
    chrdata,commands,fire,portrait,frames=art(base)
    text='FireTiles: .byte '+','.join(f'${t:02x}'for t in fire)+'\n'
    text+='LaunchX: .byte '+','.join(str(f['launch_x'])for f in frames)+'\n'
    text+='LaunchY: .byte '+','.join(str(f['launch_y'])for f in frames)+'\n'
    text+='Bounce: .byte 0,8,14,20,25,28,30,32,32,31,29,25,20,15,10,5\n'
    (P/'src/generated.inc').write_text(text)
    (P/'src/portrait.inc').write_text('PortraitTiles:\n'+''.join(' .byte '+','.join(f'${t:02x}'for t in portrait[i:i+6])+'\n'for i in range(0,len(portrait),6)))
    labels=assemble(P)
    for segment,bank,addr in [('fixed1',14,0xd860),('fixed2',15,0xf870),('fire',7,0x9160),('shadow',6,0x9d00),('portrait',9,0x8d40)]:
        data=(P/f'build/{segment}.bin').read_bytes();put(bank,addr,data,segment,bytes(len(data)))
    put(6,0x8011,commands,'Mario background animation commands',bytes(len(commands)))
    def hook(bank,addr,label,old,jsr=False):
        put(bank,addr,bytes([0x20 if jsr else 0x4c])+labels[label].to_bytes(2,'little'),label,bytes.fromhex(old))
    hook(13,0xa005,'ResetMario','4cc4a1')
    hook(11,0x8000,'RenderMario','4c2080')
    hook(11,0x8009,'PrepareMario','4c8082')
    hook(13,0xa5dc,'MarioVblank','a560f0')
    hook(13,0xa6ba,'FireCombat','201580',True)
    hook(13,0xaf0b,'PaletteUpload','a23fa0')
    hook(13,0xa867,'PortraitEntry','a9ff85')
    hook(13,0xa606,'OptionalVram','ad1004')
    hook(13,0xaae5,'FightInit','201daa',True)
    old=bytes([ord(x)-ord('A')+0x0b if x!=' 'else 0xff for x in 'LITTLE MAC'])
    name=bytes([ord(x)-ord('A')+0x0b if x!=' 'else 0xff for x in 'MARIO     '])
    for offset in [0x14c46,0x15182,0x1840f,0x19109]:
        assert rom[offset:offset+len(old)]==old
        rom[offset:offset+len(old)]=name
        changes.append(dict(file_offset=offset,size=len(old),name='Mario name'))
    rom[16+0x20000:]=chrdata
    # MMC2 supports optional CPU work RAM. It is private to the hack, never native state.
    rom[10]=7
    output=bytes(rom);(P/'dist').mkdir(exist_ok=True)
    (P/'dist'/f'{NAME}.nes').write_bytes(output);(P/'dist'/f'{NAME}.ips').write_bytes(ips(base,output))
    manifest=dict(name=NAME,rom_sha256=sha(output),output_sha256=sha(output),base_rom=str(BASE),base_sha256=sha(base),
                  labels=labels,changes=changes,reference=ref,art=json.loads((P/'build/art-map.json').read_text())['source'],
                  native=dict(MacStatus=0x50,MacPose=0x61,OppState=0x90,MacHP=0x392,OppHP=0x399),
                  adaptation='Native boxing and health, B also fires; Up+B aims high; no platform gravity.',
                  work_ram='NES 2.0 volatile 8 KiB; $6000-$6029 private state, $6400-$67ff Mac tile shadow')
    (P/'build/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Built',NAME,sha(output))
    return output,manifest
if __name__=='__main__':
    build()
