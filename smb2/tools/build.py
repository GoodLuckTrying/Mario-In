"""Build from an exact local SMB2 USA payload and a pinned disassembly."""
from pathlib import Path
import sys
import argparse,hashlib,importlib.util,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / 'tools'))
from port_paths import ensure_install_dir
REPO=ROOT.parent/'vendor/smb2'
BASE=Path('C:/nes/Super Mario Bros. 2 (USA).nes')
SMB=Path('C:/nes/Super Mario Bros. (World).nes')
SHA='41300bc4942a8a4f9b53148b404dd5cae3dd708ebdd9b617888d290a51a83e43'
SMBSHA='0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea'
COMMIT='b73415e1953d7fdffd4957d5fb43fa7a13844c1c'
NAME='SMB1 Mario and Luigi in Super Mario Bros 2'
def symbols(prefix):
    result={}
    for p in sorted(prefix.parent.glob(prefix.name+'.*.nl')):
        for line in p.read_text().splitlines():
            match=re.match(r'\$([0-9A-Fa-f]+)#([^#]+)#',line)
            if match:result[match[2]]=int(match[1],16)
    return result
def edit(source,file,before,after):
    p=source/file;s=p.read_text();assert s.count(before)==1,(file,before[:90],s.count(before));p.write_text(s.replace(before,after))
def region(source,file,start,end,replacement):
    p=source/file;s=p.read_text();a=s.index(start);b=s.index(end,a);p.write_text(s[:a]+replacement+'\n\n'+s[b:])
def assemble(source,dest):
    subprocess.run([str(REPO/'tools/asm6f.exe'),'smb2.asm','-n','-L',str(dest)],cwd=source,check=True,capture_output=True,text=True)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--install',action='store_true');args=parser.parse_args()
    old=BASE.read_bytes();smb=SMB.read_bytes()
    assert hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(smb).hexdigest()==SMBSHA
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip()==COMMIT
    for d in ['build','dist']:(ROOT/d).mkdir(exist_ok=True)
    source=ROOT/'build/source'
    shutil.copytree(REPO,source,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.git','bin','tools','*.lst','*.cdl','smusa.chr','smb2.chr'))
    (source/'smb2.chr').write_bytes(old[0x20010:])
    native=ROOT/'build/native.nes';assemble(source,native)
    assert native.read_bytes()[16:]==old[16:],'Disassembly must reproduce every original PRG/CHR byte'
    native_symbols=symbols(native)
    edit(source,'config.asm','; PLAYER_HITBOX = 1','PLAYER_HITBOX = 1')
    spec=importlib.util.spec_from_file_location('assets',ROOT.parent/'tools/build.py');assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets);assets.ROOT=ROOT;assets.graphics(smb)
    frames=(ROOT/'build/mario-frames.chr').read_bytes()
    chrout=bytearray(old[0x20010:]+bytes(128*1024))
    for pose in range(26):
        bank=bytearray(old[0x20010:0x20410])
        for slot,tile in enumerate([0,2,1,3,4,6,5,7]):bank[slot*16:(slot+1)*16]=frames[pose*128+tile*16:pose*128+(tile+1)*16]
        for slot,tile in [(8,0x64),(10,0x65)]:
            bank[slot*16:(slot+1)*16]=smb[0x8010+tile*16:0x8010+(tile+1)*16];bank[(slot+1)*16:(slot+2)*16]=bytes(16)
        chrout[(128+pose)*1024:(129+pose)*1024]=bank
    (source/'smb2.chr').write_bytes(chrout)
    edit(source,'smb2.asm','\t.db 16 ; number of 8KB CHR-ROM pages','\t.db 32 ; number of 8KB CHR-ROM pages')
    edit(source,'smb2.asm','.include "src/ram.asm"','.include "src/ram.asm"\n.include "src/mario-ram.asm"')
    for name in ['ram','control','fixed','render','fire-spawn','fire-behavior','fire-sound']:
        (source/'src'/('mario-'+name+'.asm')).write_bytes((ROOT/'src'/(name+'.asm')).read_bytes())
    land=(ROOT.parent/'src/smb-land.inc').read_text().replace('.byte','.db')
    (source/'src/mario-land.asm').write_text(land)
    p0='src/prg-0-1.asm';pf='src/prg-e-f.asm';p2='src/prg-2-3.asm'
    # Keep the native carrying/throwing routine after replacing only normal control.
    edit(source,p0,'HandlePlayerState_Normal:\n\tJSR PlayerGravity','HandlePlayerState_Normal:\n\tJSR MarioGravityGate')
    edit(source,p0,'ApplyPlayerPhysics:\n','''ApplyPlayerPhysics:
\tLDA PlayerState
\tBNE MarioPhysics_Native
\tLDA QuicksandDepth
\tCMP #2
\tBCS MarioPhysics_Native
\tCPX #0
\tBEQ MarioPhysics_X
\tCPX #$0A
\tBNE MarioPhysics_Native
\tJMP MarioApplyYGate
MarioPhysics_X:
\tJMP MarioApplyXGate
MarioPhysics_Native:
\tLDA #0
\tSTA M_PHYSICS_READY
''')
    edit(source,p0,'\tLDA PlayerDirection\n\tEOR #$01\n\tSTA PlayerDirection\n\tLDA #SoundEffect2_Climbing','\t; Mario has two distinct climbing frames; do not mirror the entire body.\n\tLDA #SoundEffect2_Climbing')
    region(source,p0,'sub_BANK0_8C1A:\n','; End of function sub_BANK0_8C1A','sub_BANK0_8C1A:\n\tJSR MarioControlGate\n\tJSR PlayerWalkJumpAnim\n\tJMP loc_BANK0_8E05\n')
    edit(source,p0,'\t; Determine bounding box lookup index\n\tLDA PlayerDucking','\t; Determine bounding box lookup index\n\tLDA PlayerDucking\n\tORA PlayerCurrentSize\n\tSTA PlayerHitbox')
    # Empty bank 7 provides banked control space without relocating level data.
    p=source/'src/prg-6-7.asm';p.write_text(p.read_text()+'\n.pad $A000, $FF\n.include "src/mario-control.asm"\n')
    edit(source,'src/prg-6-7.asm','\tLDY #$03\n\nApplyPalette_PlayerLoop:','\tLDA #$FF\n\tSTA M_PALETTE\n\tLDY #$03\n\nApplyPalette_PlayerLoop:')
    edit(source,'src/prg-a-b.asm','MarioPalette:\n\t.db $0F, $01, $16, $27','MarioPalette:\n\t.db $0F, $37, $27, $16')
    edit(source,'src/prg-a-b.asm','LuigiPalette:\n\t.db $0F, $01, $2A, $36','LuigiPalette:\n\t.db $0F, $37, $27, $19')
    # Replace the character renderer, not native enemies or their pattern banks.
    region(source,pf,'RenderPlayer:\n','; =============== S U B R O U T I N E =======================================\n\nSetAreaStartPage:',(ROOT/'src/render.asm').read_text())
    # Object collisions supply grounded state and snap the player onto heads.
    # Finish rendering afterwards so both the pose and position use that result.
    p=source/pf;s=p.read_text();a=s.index('sub_BANKF_F0F9:');b=s.index('RememberAreaInitialState:',a)
    frame=s[a:b];assert frame.count('\tJSR RenderPlayer')==3
    s=s[:a]+frame.replace('\tJSR RenderPlayer','\tJSR MarioPrepareRender')+s[b:];p.write_text(s)
    edit(source,pf,'\tJSR AreaSecondaryRoutine','\tJSR AreaSecondaryRoutine\n\tJSR MarioRenderAfterObjects')
    # Add an eight-pixel terrain box without changing any native object's box.
    edit(source,pf,'\t.db $40 ; $10 - flying carpet','\t.db $40 ; $10 - flying carpet\n\t.db $44 ; $11 - Mario fireball')
    edit(source,pf,'\t.db $10, $10, $02, $1E ; $40','\t.db $10, $10, $02, $1E ; $40\n\t.db $03, $03, $00, $07 ; $44')
    edit(source,pf,'\t.db $09, $0A, $08, $08 ; $40','\t.db $09, $0A, $08, $08 ; $40\n\t.db $00, $08, $04, $04 ; $44')
    edit(source,pf,'unusedSpace $F000, $FF','.include "src/mario-fixed.asm"\nunusedSpace $F000, $FF')
    edit(source,pf,'\nStartLevel:\n','\nStartLevel:\n\tJSR MarioReset\n')
    edit(source,pf,'\nStartGame:\n','\nStartGame:\n\tJSR MarioReset\n')
    edit(source,pf,'NMI_AfterBackgroundAttributesUpdate:\n\tJSR UpdatePPUFromBufferNMI','NMI_AfterBackgroundAttributesUpdate:\n\tJSR UpdatePPUFromBufferNMI\n\tJSR MarioPaletteNMI')
    # The only selectable native IDs are Mario (0) and Luigi (3).
    region(source,pf,'CharacterSelect_ChangeCharacter:\n','loc_BANKF_E311:','CharacterSelect_ChangeCharacter:\n\tLDA CurrentCharacter\n\tEOR #3\n\tAND #3\n\tSTA CurrentCharacter\n\tLDA #SoundEffect1_CherryGet\n\tSTA SoundEffectQueue1\n')
    edit(source,pf,'DoCharacterSelectMenu:\n','DoCharacterSelectMenu:\n\tLDA CurrentCharacter\n\tCMP #Character_Luigi\n\tBEQ MarioSelect_Valid\n\tLDA #Character_Mario\n\tSTA CurrentCharacter\nMarioSelect_Valid:\n')
    # Remove the two unused portraits from every selection animation table.
    for name,end in [('PlayerSelectToadSprites1:','PlayerSelectPrincessSprites1:'),('PlayerSelectPrincessSprites1:','PlayerSelectMarioSprites2:'),('PlayerSelectToadSprites2:','PlayerSelectPrincessSprites2:'),('PlayerSelectPrincessSprites2:','PlayerSelectSpriteIndexes:')]:
        region(source,pf,name,end,name+'\n'+('\t.db $F8,0,0,0\n'*4))
    # Center the two brothers and use SMB1 art in both menu poses.
    for name,tiles,palette,left in [('MarioSprites1',[0,2,4,6],0,104),('LuigiSprites1',[8,10,12,14],1,136),('MarioSprites2',[16,18,20,22],0,104),('LuigiSprites2',[24,26,28,30],1,136)]:
        p=source/pf;s=p.read_text();start=s.index('PlayerSelect'+name+':');end=s.index('\n\n',start)
        body='PlayerSelect'+name+':\n'+''.join(f'\t.db {143+(i//2)*16},{tile},{palette},{left+(i%2)*8}\n'for i,tile in enumerate(tiles))
        p.write_text(s[:start]+body+s[end:])
    edit(source,pf,'PlayerSelectArrowTop:\n\t.db $C9\n\t.db $D5\n\t.db $D1\n\t.db $CD','PlayerSelectArrowTop:\n\t.db $CD\n\t.db $D5\n\t.db $D1\n\t.db $D1')
    edit(source,pf,'PlayerSelectArrowBottom:\n\t.db $E9\n\t.db $F5\n\t.db $F1\n\t.db $ED','PlayerSelectArrowBottom:\n\t.db $ED\n\t.db $F5\n\t.db $F1\n\t.db $F1')
    for name,color in [('Mario','$16'),('Luigi','$19')]:
        p=source/pf;s=p.read_text();start=s.index('PlayerSelectSpritePalettes_'+name+':');end=s.index('\nPlayerSelect',start+1)
        first='$10'if name=='Mario'else'$14'
        p.write_text(s[:start]+f'PlayerSelectSpritePalettes_{name}:\n\t.db $3F,{first},4\n\t.db $0F,$37,$27,{color}'+s[end:])
    menu=bytearray(chrout[48*1024:49*1024])
    for block,pose in enumerate([0,0,11,11]):
        for slot,tile in enumerate([0,2,1,3,4,6,5,7]):menu[(block*8+slot)*16:(block*8+slot+1)*16]=frames[pose*128+tile*16:pose*128+(tile+1)*16]
    chrout[48*1024:49*1024]=menu
    (source/'smb2.chr').write_bytes(chrout)
    # Retain native 0 and 3 table slots, so statistics/ending indexing remain valid.
    # Friendly fireballs occupy real native object slots and use thrown-object damage.
    edit(source,pf,'\tJSR AreaMainRoutine','\tJSR MarioFireSpawn\n\tJSR AreaMainRoutine')
    edit(source,p2,'unusedSpace $A030, $FF','.include "src/mario-fire-spawn.asm"\nunusedSpace $A030, $FF')
    edit(source,p2,'unusedSpace $B4E0, $FF','.include "src/mario-fire-behavior.asm"\nunusedSpace $B4E0, $FF')
    edit(source,p2,'loc_BANK3_BA2A:\n\tSTA PlayerYVelocity','loc_BANK3_BA2A:\n\tJSR MarioHurtKnockback')
    edit(source,'src/prg-4-5.asm','ProcessSoundEffectQueue1:\n','ProcessSoundEffectQueue1:\n\tLDA M_FIRE_SOUND\n\tBEQ MarioFireSound_Native\n\tLDA SoundEffectQueue1\n\tBNE MarioFireSound_Cancel\n\tJMP MarioFireSound\nMarioFireSound_Cancel:\n\tLDA #0\n\tSTA M_FIRE_SOUND\nMarioFireSound_Native:\n')
    edit(source,'src/prg-4-5.asm','unusedSpace $9000, $FF','.include "src/mario-fire-sound.asm"\nunusedSpace $9000, $FF')
    edit(source,p2,'EnemyInit_BasicWithoutTimer:\n\tLDA #$00','EnemyInit_BasicWithoutTimer:\n\tLDA #0\n\tSTA M_FIRE,X\n\tLDA #$00')
    edit(source,p0,'loc_BANK0_9080:\n','loc_BANK0_9080:\n\tLDA #0\n\tSTA M_FIRE,X\n')
    edit(source,p2,'HandleEnemyState_Alive:\n','HandleEnemyState_Alive:\n\tLDA M_FIRE,X\n\tBEQ MarioFire_NotActive\n\tJMP MarioFireBehavior\nMarioFire_NotActive:\n')
    edit(source,p2,'CheckObjectCollision_ReadPlayerHitbox:\n','CheckObjectCollision_ReadPlayerHitbox:\n\tLDY byte_RAM_12\n\tLDA M_FIRE,Y\n\tBNE CheckObjectCollision_PlayerCollisionDisabled\n')
    edit(source,p2,'CheckObjectCollision_CheckOtherObjectState:\n','CheckObjectCollision_CheckOtherObjectState:\n\tLDA M_FIRE-1,X\n\tBEQ MarioFire_OtherNative\n\tJMP CheckObjectCollision_Next\nMarioFire_OtherNative:\n')
    edit(source,p2,'EnemyCollisionBehavior:\n','EnemyCollisionBehavior:\n\tLDY byte_RAM_12\n\tLDA M_FIRE,Y\n\tBEQ MarioFire_NativeHit\n\tTXA\n\tBEQ MarioFire_IgnorePlayer\n\tLDA ObjectType-1,X\n\tCMP #Enemy_VegetableSmall\n\tBCS MarioFire_IgnorePlayer\n\tJMP MarioFireHit\nMarioFire_IgnorePlayer:\n\tRTS\nMarioFire_NativeHit:\n')
    raw=ROOT/'build/patched.nes'
    try:assemble(source,raw)
    except subprocess.CalledProcessError as e:
        print(e.stdout);print(e.stderr);raise
    data=bytearray(raw.read_bytes());data[:16]=old[:16];data[5]=32
    out=bytes(data);dest=ROOT/'dist'/f'{NAME}.nes';dest.write_bytes(out)
    (ROOT/'dist'/f'{NAME}.ips').write_bytes(assets.ips(old,out))
    labels=symbols(raw)
    meta={'base_sha256':SHA,'smb_sha256':SMBSHA,'output_sha256':hashlib.sha256(out).hexdigest(),'labels':labels,'native':native_symbols,'source_commit':COMMIT,'mapper':4,'prg_kib':128,'chr_kib':256,'wram_kib':8}
    for p in [ROOT/'build/manifest.json',ROOT/'dist/build-manifest.json']:p.write_text(json.dumps(meta,indent=2))
    if (ROOT/'README.md').exists():(ROOT/'dist/README.md').write_bytes((ROOT/'README.md').read_bytes())
    if args.install:
        receipt=json.loads((ROOT/'dist/verification.json').read_text());assert receipt['passed']and receipt['rom_sha256']==meta['output_sha256']and all(c['passed']for c in receipt['checks'])
        for ext in ['nes','ips']:
            src=ROOT/'dist'/f'{NAME}.{ext}';target=ensure_install_dir()/src.name
            if target.exists()and target.read_bytes()!=src.read_bytes():
                backup=target.with_name(target.stem+' - backup '+hashlib.sha256(target.read_bytes()).hexdigest()[:8]+target.suffix)
                if not backup.exists():backup.write_bytes(target.read_bytes())
            target.write_bytes(src.read_bytes())
        for src,suffix in [(ROOT/'dist/verification.json',' - verification.json'),(ROOT/'README.md',' - Readme.txt')]:
            (ensure_install_dir()/(NAME+suffix)).write_bytes(src.read_bytes())
    print('Built',NAME,meta['output_sha256'])
if __name__=='__main__':main()
