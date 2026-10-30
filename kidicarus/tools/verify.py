"""Run the native ROM verification suite and record a hash-bound receipt."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
def main():
    logs=ROOT/'build/verification';logs.mkdir(exist_ok=True)
    tests=[]
    def check(name,args):
        start=time.time()
        result=subprocess.run([sys.executable,*args],cwd=ROOT,text=True,capture_output=True,timeout=50)
        (logs/(name+'.log')).write_text(result.stdout+result.stderr)
        print(name, 'PASS' if result.returncode==0 else 'FAIL',flush=True)
        if result.returncode:print(result.stdout+result.stderr);raise SystemExit(result.returncode)
        tests.append({'name':name,'passed':True,'seconds':round(time.time()-start,2)})
    check('physics',['tools/verify_physics.py'])
    check('fireballs',['tools/verify_fireballs.py'])
    check('collisions',['tools/verify_collisions.py'])
    for frame in [250,270,300]:
        check(f'opening-jump-{frame}',['tools/run_mesen.py','tests/opening-jump.lua','--define',f'JUMP_FRAME={frame}'])
    for mode,power in [(2,0),(3,1),(4,2),(5,0),(6,1),(7,2),(8,2)]:
        check('stage-'+str(mode),['tools/run_mesen.py','tests/stages.lua','--define',f'STAGE={mode}','--define',f'POWER={power}'])
    check('terrain',['tools/verify_terrain.py'])
    check('abilities',['tools/run_mesen.py','tests/abilities.lua'])
    check('hearts',['tools/run_mesen.py','tests/hearts.lua'])
    for power in range(3):
        for bonus in [0,1]:
            check(f'sprite-ownership-{power}-{bonus}',['tools/run_mesen.py','tests/sprite-ownership.lua','--define',f'POWER={power}','--define',f'BONUS={bonus}'])
    check('sprite-ownership-smb-item',['tools/run_mesen.py','tests/sprite-ownership.lua','--define','OWN_ITEM=true'])
    for power in [0,1]:check('bricks-'+str(power),['tools/run_mesen.py','tests/bricks.lua','--define',f'POWER={power}'])
    check('transitions',['tools/run_mesen.py','tests/transitions.lua'])
    for value in ['false','true']:check('scroll-'+value,['tools/run_mesen.py','tests/scroll.lua','--define','HORIZONTAL='+value])
    for mode in range(2,9):check(f'loading-{mode}',['tools/run_mesen.py','tests/loading.lua','--define',f'STAGE={mode}'])
    for power in range(3):
        for reaper in ['false','true']:
            check(f'stomps-{power}-{reaper}',['tools/run_mesen.py','tests/stomps.lua','--define',f'POWER={power}','--define',f'REAPER={reaper}'])
            check(f'stomp-pair-{power}-{reaper}',['tools/run_mesen.py','tests/stomps.lua','--define',f'POWER={power}','--define',f'REAPER={reaper}','--define','PAIR=true'])
        for edge in [-14,14]:
            check(f'stomp-edge-{power}-{edge}',['tools/run_mesen.py','tests/stomps.lua','--define',f'POWER={power}','--define',f'OFFSET={edge}'])
        for facing in [1,2]:
            check(f'hammers-{power}-{facing}',['tools/run_mesen.py','tests/hammers.lua','--define',f'POWER={power}','--define',f'FACING={facing}'])
    check('hammer-statue',['tools/run_mesen.py','tests/hammer-statue.lua'])
    check('performance',['tools/run_mesen.py','tests/performance.lua','--define','FIRE=true'])
    check('controller-baseline',['tools/run_mesen.py','tests/baseline.lua'])
    check('music',['tools/run_mesen.py','tests/music.lua'])
    for power in range(3):
        check(f'room-shop-{power}',['tools/run_mesen.py','tests/rooms.lua','--define',f'POWER={power}','--define','ROOM=0x26'])
    for power in [1,2]:
        check(f'room-damage-{power}',['tools/run_mesen.py','tests/rooms.lua','--define',f'POWER={power}','--define','ROOM=0x22'])
    for stage in [4,6]:
        check(f'room-shop-stage-{stage}',['tools/run_mesen.py','tests/rooms.lua','--define',f'STAGE={stage}','--define','POWER=2','--define','ROOM=0x26'])
    for stage,power in [(3,2),(5,1),(7,0)]:
        check(f'fortress-room-{stage}',['tools/run_mesen.py','tests/flicker.lua','--define',f'STAGE={stage}','--define',f'POWER={power}','--define','ROOM_GAMEPLAY=true'])
    for mode,power in [(2,0),(2,1),(2,2),(3,1),(4,2),(5,2),(6,1),(7,1),(8,2)]:
        check(f'flicker-{mode}-{power}',['tools/run_mesen.py','tests/flicker.lua','--define',f'STAGE={mode}','--define',f'POWER={power}'])
    old=Path('C:/nes/Kid Icarus (USA, Europe).nes').read_bytes()
    rom=(ROOT/'dist/Mario in Kid Icarus.nes').read_bytes()
    patch=(ROOT/'dist/Mario in Kid Icarus.ips').read_bytes()
    applied=bytearray(old);p=5
    assert patch[:5]==b'PATCH'
    while patch[p:p+3]!=b'EOF':
        offset=int.from_bytes(patch[p:p+3],'big');size=int.from_bytes(patch[p+3:p+5],'big');p+=5
        assert size,'Builder uses ordinary IPS records'
        if offset+size>len(applied):applied.extend(b'\x00'*(offset+size-len(applied)))
        applied[offset:offset+size]=patch[p:p+size];p+=size
    assert bytes(applied)==rom,'IPS must reconstruct exactly the verified ROM'
    manifest=json.loads((ROOT/'build/manifest.json').read_text())
    assert hashlib.sha256(old).hexdigest()==manifest['base_sha256']
    assert hashlib.sha256(Path('C:/nes/Super Mario Bros. (World).nes').read_bytes()).hexdigest()==manifest['smb_sha256']
    report={'rom_sha256':hashlib.sha256(rom).hexdigest(),'passed':True,'checks':tests,
            'physics':json.loads((ROOT/'build/physics-results.json').read_text()),
            'terrain':json.loads((ROOT/'build/terrain-results.json').read_text()),
            'fireballs':json.loads((ROOT/'build/fireball-results.json').read_text()),
            'collisions':json.loads((ROOT/'build/collision-results.json').read_text()),
            'ips_reconstructs_rom':True,'original_roms_unchanged':True,
            'limits':['Controlled fixtures are not an unassisted campaign clear.','The full campaign and ending have not been completed in this verification.']}
    (ROOT/'dist/verification.json').write_text(json.dumps(report,indent=2))
    print('All checks passed; originals unchanged; IPS reconstructs the ROM.',flush=True)
if __name__=='__main__':main()
