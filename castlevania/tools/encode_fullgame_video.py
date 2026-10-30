"""Encode and audit native Mesen A/V capture without editing its timeline."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
capture = ROOT / 'analysis/fullgame/stage18-credits-video.json'
report = json.loads(capture.read_text())
avi = Path(report['avi'])
video = ROOT / 'build/Mario in Castlevania - Full Playthrough.mp4'
qa = ROOT / 'analysis/video-qa'
qa.mkdir(exist_ok=True)
command = ['ffmpeg', '-hide_banner', '-y', '-i', str(avi), '-map', '0:v:0',
           '-map', '0:a:0', '-vf', 'scale=768:720:flags=neighbor,setsar=1',
           '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18',
           '-pix_fmt', 'yuv420p', '-fps_mode', 'passthrough',
           '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart',
           '-metadata', 'title=Mario in Castlevania - Full Playthrough',
           '-metadata', 'comment=Continuous verified power-on controller replay through native credits.',
           str(video)]
with (qa / 'encode.log').open('w') as log:
    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams',
                                           '-show_format', '-of', 'json', str(video)]))
v = next(s for s in probe['streams'] if s['codec_type'] == 'video')
a = next(s for s in probe['streams'] if s['codec_type'] == 'audio')
assert v['codec_name'] == 'h264' and a['codec_name'] == 'aac'
assert int(v['nb_frames']) == report['native_video_frames']
assert [v['width'], v['height']] == [768, 720]
assert abs(float(v['duration']) - float(a['duration'])) < 0.1
decode = subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i',
                         str(video), '-f', 'null', 'NUL'],
                        capture_output=True, text=True, check=True)
assert not decode.stderr.strip(), decode.stderr
volume = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(video), '-af',
                         'volumedetect', '-vn', '-f', 'null', 'NUL'],
                        capture_output=True, text=True, check=True).stderr
(qa / 'audio.log').write_text(volume)
mean = float(re.search(r'mean_volume: ([-\d.]+) dB', volume)[1])
peak = float(re.search(r'max_volume: ([-\d.]+) dB', volume)[1])
assert mean > -60 and peak > -40, 'Audio must be non-silent'
duration = float(v['duration'])
points = {'title': 2, 'opening': 20, 'middle': 450,
          'dracula': 850, 'ending': 910, 'credits': duration - 0.25}
for name, seconds in points.items():
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss',
                    str(seconds), '-i', str(video), '-frames:v', '1', '-update', '1',
                    str(qa / (name + '.png'))], check=True)
report.update({'mp4': video.as_posix(), 'mp4_sha256': hashlib.sha256(video.read_bytes()).hexdigest(),
               'mp4_bytes': video.stat().st_size, 'mp4_seconds': duration,
               'mp4_frames': int(v['nb_frames']), 'mp4_resolution': [v['width'], v['height']],
               'audio_mean_db': mean, 'audio_peak_db': peak,
               'audio_present_non_silent': True, 'timeline_unedited': True,
               'full_mp4_decode_passed': True,
               'integer_upscale': 3, 'encode_command': command,
               'qa_frames': {k: (qa / (k + '.png')).as_posix() for k in points}})
capture.write_text(json.dumps(report, indent=2))
(qa / 'ffprobe.json').write_text(json.dumps(probe, indent=2))
print(json.dumps({k: report[k] for k in ['mp4', 'mp4_bytes', 'mp4_seconds',
                                        'mp4_frames', 'audio_mean_db', 'audio_peak_db']}, indent=2))
