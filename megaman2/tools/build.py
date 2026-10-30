from pathlib import Path
import argparse,json,sys
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import *
from build_port_references import ensure_reference
P=ROOT/'megaman2';NAME='Mario in Mega Man 2';BASE=Path('C:/nes/Mega Man 2 (USA).nes')
BASE_SHA='9f5fa21062933e89c4f923d7755b6df185b054e84d9b5a6ef54216ac4dd67070'
def main():
    for d in ('build','dist','tests'): (P/d).mkdir(parents=True,exist_ok=True)
    old=BASE.read_bytes();assert sha(old)==BASE_SHA
    ensure_reference('megaman2')
    native=labels(ROOT/'build/mm2-reference/labels.txt')
    for inc in (ROOT/'vendor/mm2-reference/include').glob('*.inc'):
        for key,value in re.findall(r'^(\w+)\s*=\s*\$([\dA-Fa-f]+)',inc.read_text(),re.M):
            native.setdefault(key,int(value,16))
    (P/'src/native.inc').write_text('\n'.join(f'N_{k}=${v:04X}' for k,v in native.items() if v<=65535))
    # The engine shares low CHR tiles with drops, E-tanks and enemy bullets.
    # Preserve every such tile referenced by a non-player native metasprite.
    def byte(bank,a):return old[16+bank*16384+a-(0xC000 if bank==15 else 0x8000)]
    def word(bank,lo,hi,i):return byte(bank,lo+i)|(byte(bank,hi+i)<<8)
    protected={0,0x0F,0x1F,0x33,0x34,0x35,0x36,0x37}
    for suffix,first in [('',0x24),('_wpn',0)]:
        for typ in range(first,128):
            ptr=word(15,native['sprite_def_ptr_lo'+suffix],native['sprite_def_ptr_hi'+suffix],typ)
            if ptr<0xC000:continue
            count=byte(15,ptr)+1
            if count>64:continue
            for i in range(count):
                f=byte(15,ptr+2+i)
                if f==0:continue
                kind='wpn' if suffix else 'spr'
                frame=word(10,native[kind+'_frame_ptr_lo'],native[kind+'_frame_ptr_hi'],f)
                if not 0x8000<=frame<0xBB36:continue
                cells=byte(10,frame)
                if cells>64:continue
                for c in range(cells):
                    tile=byte(10,frame+2+c*2)
                    if tile<0x70:protected.add(tile)
    # This native-health port has one full-size form. Unused Small Mario rows
    # alias standing art, leaving shared pickup/weapon tiles completely intact.
    selected=[0,1,2,24,4,3,10,8,9,11]+[24]*8+[22,5,6,7]
    atlas=mario_atlas(P,[i for i in range(1,0x70) if i not in protected],selected=selected)
    # Explicit ordinary-enemy allowlist; bosses, traps, spikes and shields stay dangerous.
    constants=(ROOT/'vendor/mm2-reference/include/constants.inc').read_text()
    allowed=['ENTITY_SHRINK','ENTITY_M445','ENTITY_CLAW','ENTITY_CLAW_VAR','ENTITY_TANISHI_BARE','ENTITY_KEROG','ENTITY_PETIT_KEROG','ENTITY_BATTON','ENTITY_ROBBIT','ENTITY_MONKING','ENTITY_KUKKU','ENTITY_FLY_BOY','ENTITY_NEO_METALL','ENTITY_SNIPER_JOE','ENTITY_SHOTMAN','ENTITY_PIPI','ENTITY_COPIPI','ENTITY_TELLY','ENTITY_PIERROBOT','ENTITY_PETIT_GOBLIN']
    ids=[]
    for line in constants.splitlines():
        m=re.match(r'(ENTITY_\w+)\s*=\s*\$([\dA-Fa-f]+)',line)
        if m and m[1] in allowed:ids.append(int(m[2],16))
    # These source-identified regular walkers/fliers have native buster damage.
    table=[int(i in ids) for i in range(128)]
    (P/'src/stomp.inc').write_text('Stompable:\n'+ '\n'.join(' .byte '+','.join(map(str,table[i:i+16])) for i in range(0,128,16)))
    # Scene-specific uploads avoid overwriting stage CHR that shares the ROM source.
    frame=(P/'build/source-art/mario-frames.chr').read_bytes()[24*128:25*128]
    pixels=[[0]*16 for _ in range(32)]
    for cy in range(4):
      for cx in range(2):
       tile=frame[(cy*2+cx)*16:(cy*2+cx+1)*16]
       for y in range(8):
        for x in range(8):pixels[cy*8+y][cx*8+x]=((tile[y]>>(7-x))&1)|(((tile[y+8]>>(7-x))&1)<<1)
    big=bytearray()
    for cy in range(8):
     for cx in range(4):
      for plane in range(2):
       for y in range(8):big.append(sum(((pixels[(cy*8+y)//2][(cx*8+x)//2]>>plane)&1)<<(7-x) for x in range(8)))
    (P/'build/menu-title.chr').write_bytes(frame+bytes(128));(P/'build/menu-big.chr').write_bytes(big)
    (P/'src/menus.inc').write_text('MenuTitleArt:\n .incbin "build/menu-title.chr"\nMenuBigArt:\n .incbin "build/menu-big.chr"\nMenuTitlePose:\n .byte 8\n'+''.join(' .byte '+','.join(map(str,[(c//2)*8,c,0,0xCC+(c%2)*8]))+'\n' for c in range(8)))
    h=assemble(P);patch=Patcher(old,15)
    raw=(P/'build/code.bin').read_bytes();assert len(raw)<=4096,len(raw)
    packed=lz_pack(raw);assert len(packed)<=2816,len(packed)
    code=packed.ljust(2816,b'\x00')
    for bank,addr,start,size in [(15,0xF400,0,1280),(10,0xBB80,1280,1024),(14,0xBD80,2304,512)]:
        off=16+bank*16384+addr-(0xC000 if bank==15 else 0x8000)
        assert old[off:off+size]==b'\xFF'*size,(bank,hex(addr))
        patch.put(bank,addr,code[start:start+size],'Packed Mario RAM code storage')
    boot=(P/'build/boot.bin').read_bytes();assert len(boot)<=0x11D
    patch.put(15,0xF2E3,boot,'Cold boot RAM loader',b'\xFF'*len(boot))
    # Three-byte LDA is not available here: replace LDA #3 / STA lives with JSR + NOP.
    # Locate the verified hardware-init final LDA #3, STA current_lives sequence.
    sig=bytes.fromhex('A9 03 85 A8 A9 00 85 A7')
    region=old[16+14*16384:16+14*16384+0x100]
    at=region.find(sig)
    if at<0:
        lives=native['current_lives']; tanks=native['current_etanks']
        sig=bytes([0xA9,3,0x85,lives,0xA9,0,0x85,tanks]);at=region.find(sig)
    assert at>=0
    patch.put(14,0x8000+at,bytes([0x20,h['Boot']&255,h['Boot']>>8])+b'\xEA'*5,'Load Mario code and preserve native initial lives',sig)
    def hook(bank,key,target,jsr=False,delta=0):
        addr=native[key]+delta;off=16+bank*16384+addr-(0xC000 if bank==15 else 0x8000)
        patch.hook(bank,addr,h[target],target,old[off:off+3],jsr)
    hook(14,'entity_update_dispatch','Motion')
    hook(14,'ground_store_params','WaterGate')
    hook(15,'render_begin_oam_write','DrawGate')
    hook(15,'check_player_collision','ContactGate')
    # Only the update_entity_positions plain-physics call: other native callers are untouched.
    a=native['update_entity_loop'];target=native['entity_physics_core']
    region=old[16+15*16384+a-0xC000:16+15*16384+a-0xC000+60]
    i=region.index(bytes([0x20,target&255,target>>8]));hook(15,'update_entity_loop','WeaponPhysics',True,i)
    hook(15,'weapon_collision_dispatch','WeaponDispatch')
    hook(11,'weapon_boss_hit_dispatch','BossWeaponDispatch',False,4)
    # All menu CHR loads run while the native renderer is disabled.
    bank=13
    for address in range(0x8000,0xBFFE):
        sig=old[16+bank*16384+address-0x8000:][:3]
        if sig==bytes([0x20,native['chr_ram_bank_load']&255,native['chr_ram_bank_load']>>8]):
            patch.hook(bank,address,h['MenuLoad'],'Scene-owned Mario CHR upload',sig,True)
        if sig==bytes([0x20,native['title_render_megaman']&255,native['title_render_megaman']>>8]):
            patch.hook(bank,address,h['TitleDraw'],'Title Mario palette',sig,True)
    patch.put(13,native['title_megaman_def_ptr_lo'],bytes([h['MenuTitlePose']&255])*13,'Title/prologue Mario pose pointers')
    patch.put(13,native['title_megaman_def_ptr_hi'],bytes([h['MenuTitlePose']>>8])*13,'Title/prologue Mario pose pointers')
    hook(13,'weapon_get_name_colors','GetPalette')
    hook(13,'weapon_get_wait_frame','WeaponWait',True)
    # Replace the large weapon acquisition portrait, preserving the item icon.
    addr=byte(9,0x8706)|(byte(9,0x870E)<<8)
    portrait=bytearray([32])
    for cell in range(32):portrait.extend([52+(cell//4)*8,0x80+cell,0,56+(cell%4)*8])
    patch.put(9,addr,portrait,'Mario weapon acquisition portrait')
    # First player-only CHR pages, shared by every stage. Keep weapon/VFX tiles reserved.
    for tile,data in atlas.items(): patch.put(0,0x9000+tile*16,data,'SMB player atlas')
    # Palette 0 belongs to player and equipped weapon; native other palettes remain intact.
    # Replace the 12 player weapon palettes, including all three utility items.
    patch.put(15,native['weapon_palette_data'],bytes([0x0F,0x30,0x27,0x16])*12,'Fire Mario player/weapon palette')
    patch.put(14,native['tile_y_offset_table'],bytes([0xEC,0xFC,0x0B]),'Full-height Mario wall probes',bytes([0xF4,0xFC,0x0B]))
    # Rising native Y velocity probes the head; feet and all platform/ladders stay at +12.
    a=native['player_gravity_falling'];off=16+14*16384+a-0x8000
    seq=bytes.fromhex('E9 0C');i=old[off:off+20].index(seq)
    patch.put(14,a+i+1,b'\x14','Full-height Mario ceiling probe',b'\x0C')
    patch.rom[10]=7 # NES2: add 8KiB work RAM, no battery/save-format changes.
    rom=bytes(patch.rom)
    (P/'dist'/f'{NAME}.nes').write_bytes(rom);(P/'dist'/f'{NAME}.ips').write_bytes(ips(old,rom))
    manifest=dict(base_rom=str(BASE),base_sha256=BASE_SHA,smb_sha256=SMB_SHA,output_sha256=sha(rom),mapper=1,prg_kib=256,
      upstream='https://github.com/plasticsmoke/megaman2-disassembly-ca65',source_revision='da9b91ae1793db0c736f92d96554eb724882326d',
      labels=h,native=native,hooks=patch.changes,code_bytes=len((P/'build/code.bin').read_bytes()),atlas_tiles=len(atlas),protected_tiles=sorted(protected))
    (P/'build/manifest.json').write_text(json.dumps(manifest,indent=2));print(NAME,sha(rom),'code',manifest['code_bytes'])
if __name__=='__main__':main()
