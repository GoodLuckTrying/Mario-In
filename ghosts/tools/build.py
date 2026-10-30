from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from native_port_common import *
P=ROOT/'ghosts';NAME="Mario in Ghosts n Goblins";BASE=Path("C:/nes/Ghosts'n Goblins (USA).nes")
BASE_SHA='a263db625853b563aca356a8651f69c9092428dd2b665b6fd5c75ea5b1439d31'
def main():
 for d in ('build','dist','tests'):(P/d).mkdir(exist_ok=True)
 original=BASE.read_bytes();assert sha(original)==BASE_SHA
 # No usable NES source disassembly was found. All hooks are checked against
 # this exact local ROM; the research listings are exploratory, not source.
 from build import graphics
 smb=SMB.read_bytes();assert sha(smb)==SMB_SHA
 graphics(smb,output_dir=P/'build/source-art')
 (P/'build/native-startup.bin').write_bytes(original[16+7*16384+8:16+7*16384+0xC9])
 (P/'build/fire.chr').write_bytes(smb[0x8010+0x640:0x8010+0x660])
 h=assemble(P)
 image=bytearray(8192)
 code=(P/'build/code.bin').read_bytes();assert len(code)<=4096
 image[:len(code)]=code
 image[0x1000:0x1d00]=(P/'build/frames.bin').read_bytes()
 startup=(P/'build/startup.bin').read_bytes();assert len(startup)==0xc1
 image[0x1f00:0x1fc1]=startup
 for seg,offset,capacity in [('extra',0x1e40,0xc0),('extra2',0x1d80,0x80)]:
  data=(P/f'build/{seg}.bin').read_bytes();assert len(data)<=capacity
  image[offset:offset+len(data)]=data
 new=original+b'\xFF'*(8*16384);patch=Patcher(new,15)
 patch.rom[4]=16;patch.rom[10]=7
 patch.put(15,0xC000,original[-16384:],'Original engine duplicated in expanded fixed bank')
 patch.put(8,0x8000,image,'Private RAM load image')
 platform=(P/'build/platform.bin').read_bytes();assert len(platform)<=0x78
 patch.put(15,0xC050,platform,'Moving-platform grounding and protected body queue in relocated startup space',original[-16384+0x50:][:len(platform)])
 boot=(P/'build/boot.bin').read_bytes();assert len(boot)<=0xe0
 patch.put(15,0xC008,boot,'Conflict-safe RAM loader replacing relocated startup',original[-16384+8:][:len(boot)])
 def hook(bank,address,target,expected,jsr=False):patch.hook(bank,address,h[target],target,expected,jsr)
 hook(15,0xDA71,'Spawn','A2 00 BD')
 hook(4,0x8007,'Collect','BD F0 04')
 hook(4,0x80D0,'DrawGate','A0 02 B1')
 hook(15,0xC10D,'DmaPage','8D 14 40',True)
 hook(15,0xC1CF,'NmiArt','A5 5A D0')
 hook(15,0xC209,'NmiPalette','AD 02 20',True)
 hook(15,0xDAE4,'PlayerLoop','20 5B DC')
 hook(15,0xF5A0,'WeaponHit','20 FF F2')
 hook(15,0xF687,'ContactGate','20 FF F2')
 hook(4,0x804C,'RenderAll','20 D0 80',True)
 hook(4,0xA561,'GhostHit','B9 F1 05')
 hook(15,0xDDF7,'LadderJump','20 11 F3')
 hook(4,0xB7FA,'PlatformGround','20 81 F1',True)
 hook(4,0xB957,'PlatformGround','20 81 F1',True)
 hook(15,0xE5C0,'QueueBody','20 CF EE',True)
 hook(15,0xEEF1,'CapturePalette','99 20 07',True)
 hook(4,0x8000,'BeginRender','20 89 80',True)
 hook(4,0x8089,'FinishRender','AD F0 04')
 rom=bytes(patch.rom);(P/'dist'/(NAME+'.nes')).write_bytes(rom);(P/'dist'/(NAME+'.ips')).write_bytes(ips(original,rom))
 native={k:int(v,16)for k,v in re.findall(r'N_(\w+)=\$([0-9A-Fa-f]+)',(P/'src/native.inc').read_text())}
 manifest=dict(base_rom=str(BASE),base_sha256=BASE_SHA,smb_sha256=SMB_SHA,output_sha256=sha(rom),mapper=2,submapper=2,prg_kib=256,work_ram_kib=8,labels=h,native=native,hooks=patch.changes,code_bytes=len(code),source_method='Verified byte hooks in original ROM; no external NES disassembly available',startup_relocation=dict(original_cpu=0xC008,ram_cpu=0x7F00,size=0xc1,relative_branches_preserved=True))
 manifest['source_revision']='smb1base 46ff88f7d9e854db80bf8d50e5bf74340fcc64ce; USE_SMB2J_FEATURES=0'
 manifest['physics_clock']='SMB steps catch up for elapsed NMIs, capped at three per native coroutine update; native rendering cadence retained'
 (P/'build/manifest.json').write_text(json.dumps(manifest,indent=2));print(NAME,sha(rom),'code',len(code))
if __name__=='__main__':main()
