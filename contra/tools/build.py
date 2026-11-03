"""Build the Mario/Luigi Contra ROM from the user's verified local originals."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'tools'))
from port_paths import ensure_install_dir
sys.path.insert(0,str(ROOT/'tools'))
from native import CC65,BASE,SHA
sys.path.insert(0,str(ROOT.parent/'tools'))
from build import ips
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
    base=BASE.read_bytes();assert hashlib.sha256(base).hexdigest()==SHA
    smb=Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()
    assert hashlib.sha256(smb).hexdigest()=='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
    (ROOT/'build').mkdir(exist_ok=True);(ROOT/'dist').mkdir(exist_ok=True)
    symbols=json.loads((ROOT/'build/native-symbols.json').read_text())
    aliases={name:item['address'] for name,item in symbols.items()}
    aliases['BANK_NUMBER']=0x8000
    (ROOT/'src/native.inc').write_text('\n'.join(f'N_{name}=${addr:04X}' for name,addr in aliases.items())+'\n')
    state=[]
    for line in (ROOT.parent/'src/memory.inc').read_text().splitlines():
        m=re.fullmatch(r'(M_\w+)=\$68([0-9A-F]{2})',line)
        if m and int(m[2],16)<=0x45:state.append(f'{m[1]}=BASE+${m[2]}')
    state.append('M_TRANSFORM=BASE+$46')
    state.extend(['M_SWIMMING=BASE+$47','M_SWIM_TIMER=BASE+$48','M_STOMP_GRACE=BASE+$49','M_STOMP_CHAIN=BASE+$4A','M_SCROLL=BASE+$4B'])
    state.append('M_SUPPLIES=BASE+$4C')
    state.append('M_WATER_LEVEL=BASE+$4D')
    state.extend(['M_SCRIPT=BASE+$4E','M_DX=BASE+$4F','M_START_X=BASE+$50'])
    state.extend(['M_LOOKUP_Y=BASE+$51','M_LOOKUP_ROW=BASE+$52'])
    (ROOT/'src/state.inc').write_text('\n'.join(state)+'\n')
    (ROOT/'src/smb-land.inc').write_text((ROOT.parent/'src/smb-land.inc').read_text())
    (ROOT/'src/morph.inc').write_text((ROOT.parent/'src/morph.inc').read_text())
    # Reuse the verified SMB1 tile extraction, then arrange tiles as 8x16 pairs.
    import importlib.util
    spec=importlib.util.spec_from_file_location('icarus_assets',ROOT.parent/'tools/build.py')
    assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets)
    assets.graphics(smb)
    frames=(ROOT.parent/'build/mario-frames.chr').read_bytes()
    reordered=bytearray()
    for pos in range(0,len(frames),128):
        frame=frames[pos:pos+128]
        for tile in (0,2,1,3,4,6,5,7):reordered+=frame[tile*16:tile*16+16]
    import title_assets
    title_info=title_assets.build()
    import sprite_assets
    graphics=sprite_assets.build(bytes(reordered),base,aliases)
    chr=smb[0x8010:];items=bytearray()
    for tiles in [(0x76,0x77,0x78,0x79),(0xD6,0xD6,0xD9,0xD9)]:
        for i in (0,2,1,3):
            data=chr[tiles[i]*16:tiles[i]*16+16]
            if tiles[0]==0xD6 and i%2:data=bytes(int(f'{b:08b}'[::-1],2) for b in data)
            items+=data
    (ROOT/'build/items.chr').write_bytes(items)
    (ROOT/'build/fire.chr').write_bytes(chr[0x64*16:0x65*16]+bytes(16))
    source=(ROOT.parent/'vendor/contra-us/src/bank7.asm').read_text()
    groups=['enemy_routine_level_1','enemy_routine_level_2_4','enemy_routine_level_3','enemy_routine_level_2_4',
            'enemy_routine_level_5','enemy_routine_level_6','enemy_routine_level_7','enemy_routine_level_8']
    stompable=bytearray(256)
    for level,group in enumerate(groups):
        for kind in [3,4,5,6,7,8,10,12,14]:stompable[level*32+kind]=1
        block=source.split(group+':',1)[1].split('\n\n',1)[0]
        names=re.findall(r'\.addr\s+(\w+)',block)
        for kind,name in enumerate(names,16):
            if not any(word in name for word in ['bullet','projectile','grenade','flame','bubble','fire','bridge','rock','cart','laser','gen_','claw','spiked']):
                stompable[level*32+kind]=2 if any(word in name for word in ['boss','tank','guardian','heart']) else 1
    (ROOT/'build/stompable.bin').write_bytes(stompable)
    subprocess.run([str(CC65/'ca65.exe'),'src/mario.s','-I','src','-I','.','-o','build/mario.o','-l','build/mario.lst'],cwd=ROOT,check=True)
    subprocess.run([str(CC65/'ld65.exe'),'-C','src/hack.cfg','build/mario.o','-Ln','build/labels.txt','-m','build/map.txt'],cwd=ROOT,check=True)
    labels={m[1]:int(m[0],16) for m in re.findall(r'al ([0-9A-Fa-f]+) \.(\w+)',(ROOT/'build/labels.txt').read_text())}
    rom=bytearray(base[:16]+base[16:]+b'\xFF'*(8*16384));rom[4]=16;rom[10]=7
    rom[16+15*16384:]=base[16+7*16384:]
    rom[16+8*16384:16+9*16384]=(ROOT/'build/bank8.bin').read_bytes()
    angle_chr=(ROOT/'build/angle-rifles.chr').read_bytes()+(ROOT/'build/base-back-frames.chr').read_bytes()
    rom[16+9*16384:16+9*16384+1+len(angle_chr)]=bytes([9])+angle_chr
    rom[16+10*16384:16+11*16384]=(ROOT/'build/bank10.bin').read_bytes()
    def put(bank,addr,data):
        offset=16+bank*16384+addr-(0xC000 if bank==15 else 0x8000)
        rom[offset:offset+len(data)]=data
    def hook(name,label,op=0x4C):
        addr=aliases[name];a=labels[label];put(15,addr,bytes([op,a&255,a>>8]))
    put(15,0xF612,(ROOT/'build/fixed.bin').read_bytes())
    put(15,0xFFD0,bytes(range(16)))
    for original,label in [('init_APU','Boot'),('configure_PPU','AssetsGate'),('player_state_routine_01_logic','MoveGate'),('load_bank_2_set_player_sprite','RenderGate'),('load_bank_6_check_player_fire','FireGate'),('load_bank_6_run_player_bullet_routines','BulletGate'),('kill_player','DamageGate'),('pick_up_weapon_item','PickupGate'),('init_player_and_weapon','ResetGate'),('write_palette_colors_to_ppu','PaletteGate'),('scroll_player','ScrollGate'),('check_player_solid_bg_collision','SolidGate')]:hook(original,label)
    # Use the complete supplied title, preserving native mode/demo state.
    for index,label in [(0,'TitleInit'),(1,'TitleOne'),(3,'TitleThree'),(4,'TitleFour')]:
        a=labels[label];put(15,aliases['game_routine_pointer_table']+index*2,a.to_bytes(2,'little'))
    hook('load_intro_palette2_play_intro_sound','TitleTheme')
    hook('set_ppu_scroll','TitleScroll')
    addr=aliases['load_intro_graphics'];old_call=bytes([0x20,addr&255,addr>>8])
    source_fixed=base[16+7*16384:]
    # The demo-interrupt route calls the original loader directly.
    start=aliases['stop_demo_load_player_select_UI']-0xC000
    at=source_fixed.index(old_call,start,start+32);a=labels['TitleGate']
    put(15,0xC000+at,bytes([0x20,a&255,a>>8]))
    # Replace the NMI's DMA setup and its call to the native sprite renderer.
    pause=aliases['check_for_pause'];call=bytes([0x20,pause&255,pause>>8]);native=base[16+7*16384:]
    assert native.count(call)==1
    target=labels['PauseGate'];put(15,0xC000+native.index(call),bytes([0x20,target&255,target>>8]))
    old=bytes.fromhex('8D 03 20 A0 02 8C 14 40');native=base[16+7*16384:];at=native.find(old);assert at>=0
    a=labels['DmaGate'];put(15,0xC000+at,bytes([0x20,a&255,a>>8])+b'\xEA'*5)
    draw=aliases['draw_sprites'];call=bytes([0x20,draw&255,draw>>8]);at=native.find(call,aliases['nmi_start']-0xC000);assert at<0x100
    a=labels['DrawGate'];put(15,0xC000+at,bytes([0x20,a&255,a>>8]))
    # Retire the last terrain command before switching the demo's buffer
    # to title text format. Mario can scroll on the final recorded frame.
    start=aliases['game_routine_02']-0xC000
    end=aliases['game_routine_03']-0xC000
    old=bytes([0xA9,0,0x85,aliases['GRAPHICS_BUFFER_MODE'],0xF0])
    at=native.index(old,start,end);assert at+6==end
    a=labels['DemoEndGate'];put(15,0xC000+at,bytes([0x4C,a&255,a>>8])+b'\xEA'*3)
    # Demo and real-game setup both begin by clearing native internal RAM.
    # Reset the added WRAM player state at the same session boundary.
    clear=aliases['clear_memory_3'];old=bytes([0x20,clear&255,clear>>8])
    for name in ['set_next_demo_level','init_score_player_lives']:
        at=aliases[name]-0xC000;assert native[at:at+3]==old
        a=labels['SessionGate'];put(15,aliases[name],bytes([0x20,a&255,a>>8]))
    # Keep the collision loop's entry and its internal back-edge intact.
    addr=aliases['exe_enemy_routine'];call=bytes([0x20,addr&255,addr>>8]);assert native.count(call)==1
    a=labels['EnemyGate'];put(15,0xC000+native.index(call),bytes([0x20,a&255,a>>8]))
    addr=aliases['set_enemy_collision_box'];call=bytes([0x20,addr&255,addr>>8])
    at=native.index(call,aliases['check_players_collision']-0xC000)
    assert at<aliases['bullet_enemy_collision_test']-0xC000
    a=labels['PlayerBoxGate'];put(15,0xC000+at,bytes([0x20,a&255,a>>8]))
    # Render directly into the final DMA page. Reserve Mario/fireball slots
    # inside the native permutation instead of copying/compacting 64 sprites
    # after every draw. Non-game screens still use the full native 64 slots.
    sprite=bytearray(base[16+16384:16+2*16384])
    first=aliases['draw_sprites']-0x8000
    last=aliases['sprite_ptr_tbl_0']-0x8000
    for low in range(4):
        old=bytes([0x9D,low,2]);new=bytes([0x9D,low,0x64])
        for pos in range(first,last-2):
            if sprite[pos:pos+3]==old:put(1,0x8000+pos,new)
    prologue=bytes([0xA5,aliases['OAMDMA_CPU_BUFFER_OFFSET'],0x18,0x69,0x4C,
                    0x85,aliases['OAMDMA_CPU_BUFFER_OFFSET'],0x85,4,0xA0,0x3F,0x84,7])
    assert sprite[first:first+len(prologue)]==prologue
    a=labels['OamStartGate'];put(1,aliases['draw_sprites'],bytes([0x20,a&255,a>>8])+b'\xEA'*(len(prologue)-3))
    a=labels['OamAdvanceGate'];put(1,aliases['adv_OAMDMA_addr'],bytes([0x4C,a&255,a>>8]))
    # Keep signed screen X when a collapsing bridge falls behind the camera.
    # The continuation follows its unchanged native queue/address prologue.
    entry=aliases['update_nametable_supertile']-0xC000
    assert native[entry:entry+11]==bytes.fromhex('85 11 A5 21 C9 40 B0 F7 20 BB C7')
    bridge=base[16:16+16384]
    call=bytes([0x20,aliases['load_bank_3_update_nametable_supertile']&255,aliases['load_bank_3_update_nametable_supertile']>>8])
    start=aliases['exploding_bridge_routine_01']-0x8000
    end=aliases['exploding_bridge_exit']-0x8000
    at=bridge.index(call,start,end);assert bridge.count(call,start,end)==1
    a=labels['BridgeTileGate'];put(0,0x8000+at,bytes([0x20,a&255,a>>8]))
    # Two unused native metasprites become mushroom and flower definitions.
    extra=aliases['bank_1_unused_space']
    # Keep the actual lift under Mario during both base endings, removing
    # only the original soldier shared after its first three lift tiles.
    lift=aliases['sprite_91'];put(1,lift,bytes([3]))
    for sprite,first in [(0x4F,0x38),(0x65,0x3C)]:
        pointer=aliases['sprite_ptr_tbl_0']+(sprite-1)*2
        put(1,pointer,extra.to_bytes(2,'little'))
        data=bytes([2,0xF0,first,0,0xF8,0xF0,first+2,0,0])
        put(1,extra,data);extra+=len(data)
    out=ROOT/'dist/Mario and Luigi in Contra.nes';out.write_bytes(rom)
    (ROOT/'dist/Mario and Luigi in Contra.ips').write_bytes(ips(base,rom))
    report={'base_sha256':SHA,'smb_sha256':hashlib.sha256(smb).hexdigest(),'output_sha256':hashlib.sha256(rom).hexdigest(),'labels':labels,'native':aliases,'mapper':2,'prg_kib':256,'wram_kib':8,'source_commit':'687d651c021fd7020f10d05b970ccb62663c94bd'}
    report['graphics']=graphics
    report['title_art']=title_info
    (ROOT/'build/manifest.json').write_text(json.dumps(report,indent=2))
    (ROOT/'dist/build-manifest.json').write_text(json.dumps(report,indent=2))
    (ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
    if args.install:
        verification=ROOT/'dist/verification.json'
        assert verification.exists(),'Verify the candidate before installing it'
        receipt=json.loads(verification.read_text())
        assert receipt.get('rom_sha256')==report['output_sha256'] and receipt.get('passed') and receipt.get('checks') and all(check['passed'] for check in receipt['checks']),'Installation requires every check to pass for this exact ROM'
        for ext in ['nes','ips']:
            source=out.with_suffix('.'+ext);dest=ensure_install_dir()/source.name
            if dest.exists() and dest.read_bytes()!=source.read_bytes():
                backup=dest.with_name(dest.stem+' - backup '+hashlib.sha256(dest.read_bytes()).hexdigest()[:8]+dest.suffix)
                if not backup.exists():backup.write_bytes(dest.read_bytes())
            dest.write_bytes(source.read_bytes())
        (ensure_install_dir()/'Mario and Luigi in Contra - Readme.txt').write_bytes((ROOT/'README.md').read_bytes())
        verification=ROOT/'dist/verification.json'
        if verification.exists():
            receipt=json.loads(verification.read_text())
            if receipt.get('rom_sha256')==report['output_sha256'] and receipt.get('passed') and all(check['passed'] for check in receipt['checks']):
                (ensure_install_dir()/'Mario and Luigi in Contra - verification.json').write_bytes(verification.read_bytes())
    print('Built Contra Mario/Luigi:',report['output_sha256'])
if __name__=='__main__':main()
