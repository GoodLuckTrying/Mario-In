"""Refresh proof/source metadata without reinstalling or changing ROM history."""
from pathlib import Path
import hashlib,json,zipfile
ROOT=Path(__file__).resolve().parents[1]
installed=Path('C:/nes/Mario In/Mario in Castlevania.nes')
sha=hashlib.sha256(installed.read_bytes()).hexdigest()
proof=json.loads((ROOT/'analysis/fullgame-results.json').read_text())
assert proof['candidate_sha256']==sha and proof['full_game_clear'] and proof['fresh_boot_verified']
release_path=ROOT/'analysis/release-dracula-head.json'
release=json.loads(release_path.read_text())
assert release['installed_sha256']==sha
release['fullgame_evidence']=proof
release['limitations']=['II/III holy water pickup and capacity checks use controlled native fixtures; the live boss fight uses single holy water','The verified continuous full-game controller route includes four ordinary deaths']
release_path.write_text(json.dumps(release,indent=2))
target=ROOT/'build/source-verified-dracula-head.zip'
temporary=ROOT/'build/source-verified-dracula-head.repacked.zip'
assert target.resolve().parent==temporary.resolve().parent==ROOT/'build'
with zipfile.ZipFile(target,'r') as old,zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED) as new:
    names=set()
    for item in old.infolist():
        names.add(item.filename)
        path=ROOT/item.filename
        if path.is_file(): new.write(path,item.filename)
        else: new.writestr(item,old.read(item.filename))
    route=json.loads((ROOT/'analysis/fullgame/stage18-credits-route.json').read_text())
    for segment in route['segments']:
        for suffix in ('.json','.config.json','-input.csv'):
            name='analysis/fullgame/'+segment+suffix
            path=ROOT/name
            if path.exists() and name not in names: new.write(path,name);names.add(name)
    # Keep the recording reproducible; the large MP4 is delivered separately.
    for name in (
        'tools/record_fullgame.py', 'tools/encode_fullgame_video.py',
        'tools/mesen_capture_bridge.c', 'build/mesen_capture_bridge.dll',
        'analysis/fullgame/stage18-credits-video.json',
        'analysis/fullgame/stage18-credits-video.lua',
        'analysis/fullgame/stage18-credits-video.log',
        'analysis/fullgame/stage18-credits-video-trace.csv',
        'analysis/video-qa/ffprobe.json', 'analysis/video-qa/audio.log',
        'analysis/video-qa/encode.log',
    ):
        path=ROOT/name
        if path.exists() and name not in names: new.write(path,name);names.add(name)
temporary.replace(target)
assert hashlib.sha256(installed.read_bytes()).hexdigest()==sha
print(f'Installed ROM and full-game proof agree: {sha}; source and fixed-input replay package refreshed.')
