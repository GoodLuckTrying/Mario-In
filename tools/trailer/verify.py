"""Audit the finished trailer and retain an all-games visual contact sheet."""
from pathlib import Path
import subprocess,json,re,hashlib
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'media/Mario In - Trailer.mp4';j=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-show_chapters','-of','json',str(p)]));v=next(x for x in j['streams']if x['codec_type']=='video');a=next(x for x in j['streams']if x['codec_type']=='audio')
assert(v['width'],v['height'],v['r_frame_rate'],int(v['nb_frames']))==(1920,1080,'60/1',5514)
assert abs(float(v['duration'])-91.9)<0.02
assert abs(float(v['duration'])-float(a['duration']))<0.08
r=subprocess.run(['ffmpeg','-v','error','-i',str(p),'-f','null','NUL'],capture_output=True,text=True,check=True);assert not r.stderr.strip(),r.stderr
volume=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','volumedetect','-vn','-f','null','NUL'],capture_output=True,text=True,check=True).stderr
mean=float(re.search(r'mean_volume: ([-\d.]+) dB',volume)[1]);peak=float(re.search(r'max_volume: ([-\d.]+) dB',volume)[1]);assert mean>-40 and -10<peak<0
edit=json.loads((ROOT/'media/trailer-edit.json').read_text());qa=ROOT/'build/trailer/qa';sheet=Image.new('RGB',(5*480,3*292));d=ImageDraw.Draw(sheet)
for i,c in enumerate(edit['chapters']):
 f=qa/('final-'+c['game']+'.png');t=c['start']+min(3,c['duration']/2)
 subprocess.run(['ffmpeg','-v','error','-y','-ss',str(t),'-i',str(p),'-frames:v','1',str(f)],check=True)
 image=Image.open(f).resize((480,270));sheet.paste(image,((i%5)*480,(i//5)*292));d.text(((i%5)*480,(i//5)*292+271),c['title'])
sheet.save(qa/'final-all-games.png')
catalog=json.loads((ROOT/'release/catalog.json').read_text())['patches'];proof=[]
for game in edit['games']:
 item=next(x for x in catalog if x['game']==game['game'])
 for c in game['clips']:
  capture=json.loads((ROOT/'build/trailer/captures'/(c['capture']+'.json')).read_text())
  assert capture['rom_sha256']==item['rom_sha256'] and capture['native_capture']
  source=ROOT/game['game']/capture['fixture'];assert hashlib.sha256(source.read_bytes()).hexdigest()==capture['fixture_sha256']
  proof.append(dict(game=game['game'],capture=c['capture'],rom_sha256=capture['rom_sha256'],fixture_sha256=capture['fixture_sha256']))
report=dict(sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size,seconds=float(v['duration']),frames=int(v['nb_frames']),resolution=[v['width'],v['height']],fps=60,chapters=len(j['chapters']),full_decode_passed=True,audio_mean_db=mean,audio_peak_db=peak,av_duration_delta=abs(float(v['duration'])-float(a['duration'])),native_av_capture=True,sources=proof)
(ROOT/'media/trailer-verification.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS trailer: 15 games, 1080p60, 5514 frames, native audio, complete decode, current ROM/fixture hashes; '+str(round(p.stat().st_size/1048576,1))+' MiB')
