"""Pixel-identical display frame from opaque native checkpoints, old vs new.

This is directed rendering verification, not a controller clear. The first
complete post-load frame displays the checkpoint's prepared OAM and VRAM.
"""
from pathlib import Path
import hashlib,json,subprocess,sys
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[1]
REFERENCE=ROOT/'build/previous-installed/a0f346441b7f/Mario in Castlevania.nes'
CASES=['stage3-bat-ledge-fight','stage4-first-stair','stage5-top-stairs',
       'stage10-cave-live','stage12-healthy-arena','stage14-upper-left-hall',
       'stage14-west-corridor','stage18-credits-fresh']
def main():
    rom=Path(sys.argv[1]).resolve();out=ROOT/'analysis/physics-fix-2026-10-23/raster';out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for case in CASES:
        state=ROOT/f'analysis/fullgame/{case}.state';assert state.exists(),state
        for tag,target in [('original',REFERENCE),('candidate',rom)]:
            stem=out/f'{case}-{tag}'
            source=r'''
local loaded=false;local n=0
local h=assert(io.open(STATE,'rb'));local s=h:read('*a');h:close()
emu.addMemoryCallback(function() if not loaded then loaded=true;emu.loadSavestate(s) end end,emu.callbackType.exec,0xc0b5)
emu.addEventCallback(function() emu.setInput({},0) end,emu.eventType.inputPolled)
emu.addEventCallback(function()
 if not loaded then return end
 n=n+1
 if n==3 then local h=assert(io.open(SHOT,'wb'));h:write(emu.takeScreenshot());h:close();print('Complete displayed frame captured');emu.stop(0) end
end,emu.eventType.endFrame)
'''.replace('STATE',json.dumps(state.as_posix())).replace('SHOT',json.dumps(stem.with_suffix('.png').as_posix()))
            script=stem.with_suffix('.lua');script.write_text(source)
            r=subprocess.run([sys.executable,str(ROOT/'tools/run_mesen.py'),str(script),str(target),'--timeout=10'],capture_output=True,text=True,timeout=25)
            stem.with_suffix('.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stdout+r.stderr
        a,b=[Image.open(out/f'{case}-{tag}.png').convert('RGB') for tag in ('original','candidate')]
        box=ImageChops.difference(a,b).getbbox()
        rows.append({'checkpoint':case,'passed':box is None,'difference_bounds':box})
        print(case, 'IDENTICAL' if box is None else str(box),flush=True)
    report={'candidate_sha256':hashlib.sha256(rom.read_bytes()).hexdigest(),
            'reference_sha256':hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
            'passed':all(r['passed'] for r in rows),'cases':rows,
            'evidence':'Opaque checkpoint display comparison; complete rendered frame, all 61,440 pixels, no framebuffer or RAM changes; not a new full-game clear'}
    (out/'results.json').write_text(json.dumps(report,indent=2));assert report['passed'],rows
if __name__=='__main__':main()
