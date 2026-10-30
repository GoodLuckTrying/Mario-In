"""Render the reproducible 1080p60 gameplay trailer from native A/V captures."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,array,hashlib,json,math,subprocess,textwrap,wave
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'build/trailer';CAP=WORK/'captures';MEDIA=ROOT/'media';CFG=json.loads((ROOT/'tools/trailer/edit.json').read_text())
W,H=CFG['resolution'];FPS=CFG['fps'];BG=(10,16,29);WHITE=(246,243,233);MUTED=(157,173,194);RED=(255,81,67);GREEN=(74,224,155)
FONT=Path('C:/Windows/Fonts/bahnschrift.ttf')
def font(size):return ImageFont.truetype(str(FONT),size)
def run(command,log):
 with log.open('w')as out:subprocess.run(command,stdout=out,stderr=subprocess.STDOUT,check=True)
def text(draw,xy,value,size,color=WHITE,spacing=10):draw.multiline_text(xy,value,font=font(size),fill=color,spacing=spacing)
def frame_at(tag,seconds,target):
 run(['ffmpeg','-v','error','-y','-ss',str(seconds),'-i',str(CAP/(tag+'.avi')),'-frames:v','1',str(target)],target.with_suffix('.log'))
def panel(index,game):
 image=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(image)
 for y in range(0,H,48):d.line((0,y,W,y),fill=(13,21,36))
 d.rectangle((0,0,14,H),fill=RED)
 text(d,(72,55),'MARIO IN',38);text(d,(72,120),'15 GAMES / NEW MOVES',21,MUTED)
 text(d,(72,205),f'{index+1:02d} / 15',30,RED)
 title=game['title'];size=68
 while max(d.textlength(line,font=font(size))for line in title.splitlines())>660:size-=1
 text(d,(72,270),title,size,spacing=14)
 lines=len(title.splitlines());y=max(540,270+lines*(size+14)+40)
 d.rectangle((72,y,130,y+5),fill=GREEN)
 text(d,(72,y+35),'WHAT MARIO CHANGES',23,GREEN)
 mechanics='\n'.join('\n'.join(textwrap.wrap(line,34))for line in game['mechanics'].splitlines())
 text(d,(72,y+86),mechanics,34,spacing=16)
 text(d,(72,930),game['tagline'],23,MUTED)
 d.rectangle((796,56,1827,1023),outline=(60,77,99),width=4)
 for i in range(15):
  x=72+i*118;d.rectangle((x,1044,x+104,1051),fill=RED if i<=index else(37,49,67))
 target=WORK/f'panel-{index:02}.png';image.save(target);return target

def jingle(path,seconds,final=False):
 rate=48000;out=array.array('h');notes=[60,64,67,72,71,67,64,67,60,64,69,72,67,64,62,60]
 for n in range(round(seconds*rate)):
  t=n/rate;beat=int(t/.18);phase=(t/.18)%1;note=notes[beat%len(notes)];hz=440*2**((note-69)/12)
  envelope=min(1,phase*24)*max(0,1-phase)**.8
  lead=(1 if math.sin(2*math.pi*hz*t)>=0 else-1)*.11*envelope
  bass=.035*math.sin(2*math.pi*130.8128*t)
  tail=min(1,t/.04,max(0,(seconds-t)/.2))
  value=int(32767*(lead+bass)*tail)
  out.extend((value,value))
 with wave.open(str(path),'wb')as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(rate);w.writeframes(out.tobytes())

def title_card(outro=False):
 im=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(im);d.rectangle((0,0,14,H),fill=RED)
 for i in range(15):d.rectangle((72+i*39,95,96+i*39,119),fill=RED if i%2==0 else GREEN)
 text(d,(72,165),'FAN-MADE NES CROSSOVERS',29,MUTED)
 if not outro:
  text(d,(66,265),'MARIO',166);text(d,(66,440),'IN.',166,RED)
  text(d,(72,700),'15 worlds. New moves.',41)
  text(d,(72,775),'Jump. Stomp. Make trouble.',29,MUTED)
 else:
  text(d,(68,280),'15 GAMES.',100);text(d,(68,400),'MARIO RULES.',88,RED)
  text(d,(72,615),'Sources + current IPS patches',34)
  text(d,(72,680),'github.com/kandowontu2',30,GREEN)
  text(d,(72,726),'/Mario-In',43,GREEN)
  text(d,(72,815),'SPRITE SHEET',20,GREEN)
  text(d,(72,845),' + '.join(CFG['credits']['sprite_sheet']),30)
  text(d,(72,895),'TESTING',20,GREEN)
  text(d,(72,925),' + '.join(CFG['credits']['testing']),30)
 for i,g in enumerate(CFG['games']):
  tile=WORK/('thumb-'+g['game']+'.png');clip=g['clips'][0]
  if not tile.exists():frame_at(clip['capture'],clip['start']+min(1.2,clip['duration']/2),tile)
  x=832+(i%5)*202;y=250+(i//5)*218
  im.paste(Image.open(tile).convert('RGB').resize((192,180),Image.Resampling.NEAREST),(x,y))
  d.rectangle((x,y,x+191,y+179),outline=(48,65,85),width=2)
  label=g['title'].replace('\n',' ')
  if len(label)>22:label=label[:20]+'..'
  text(d,(x,y+185),label,14,MUTED)
 text(d,(72,995),'MARIO IN  /  GAMEPLAY SHOWCASE',22,MUTED)
 file=WORK/('outro.png'if outro else'intro.png');im.save(file);return file

ENC=['-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-c:a','pcm_s16le','-ar','48000','-ac','2']
def render_game(index,game):
 duration=round(sum(c['duration']for c in game['clips']),3);target=WORK/f'game-{index:02}.mkv';bg=panel(index,game);cmd=['ffmpeg','-hide_banner','-y'];filters=[]
 for i,c in enumerate(game['clips']):
  cmd+=['-i',str(CAP/(c['capture']+'.avi'))]
  filters.append(f'[{i}:v]trim=start={c["start"]}:duration={c["duration"]},setpts=PTS-STARTPTS,fps={FPS},scale=1024:960:flags=neighbor,setsar=1[v{i}]')
  filters.append(f'[{i}:a]atrim=start={c["start"]}:duration={c["duration"]},asetpts=PTS-STARTPTS,aresample=48000[a{i}]')
 n=len(game['clips']);cmd+=['-loop','1','-framerate',str(FPS),'-i',str(bg)]
 if n>1:
  filters.append(''.join(f'[v{i}][a{i}]'for i in range(n))+f'concat=n={n}:v=1:a=1[game][sound]');v='game';a='sound'
 else:v='v0';a='a0'
 filters.append(f'[{n}:v][{v}]overlay=800:60:shortest=1,format=yuv420p[video]')
 filters.append(f'[{a}]afade=t=in:st=0:d=0.04,afade=t=out:st={duration-.08}:d=0.08,loudnorm=I=-18:TP=-2:LRA=9[audio]')
 cmd+=['-filter_complex',';'.join(filters),'-map','[video]','-map','[audio]','-t',str(duration),'-r',str(FPS),*ENC,str(target)]
 run(cmd,WORK/f'game-{index:02}-encode.log');print('RENDERED '+game['game'],flush=True);return target

def render_card(outro=False):
 duration=CFG['outro_seconds'if outro else'intro_seconds'];name='outro'if outro else'intro';png=title_card(outro);wav=WORK/(name+'.wav');jingle(wav,duration,outro)
 target=WORK/(name+'.mkv')
 run(['ffmpeg','-hide_banner','-y','-loop','1','-framerate',str(FPS),'-i',str(png),'-i',str(wav),'-vf',f'fade=t=in:st=0:d=0.18,fade=t=out:st={duration-.25}:d=0.25','-t',str(duration),'-r',str(FPS),*ENC,str(target)],WORK/(name+'-encode.log'));return target

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--cards-only',action='store_true');parser.add_argument('--outro-only',action='store_true');parser.add_argument('--game',choices=[g['game']for g in CFG['games']]);args=parser.parse_args();WORK.mkdir(parents=True,exist_ok=True);MEDIA.mkdir(exist_ok=True)
 if args.cards_only:
  title_card();title_card(True)
  for i,g in enumerate(CFG['games']):panel(i,g)
  return
 intro=WORK/'intro.mkv';outro=WORK/'outro.mkv'
 if args.outro_only:
  outro=render_card(True)
 elif args.game:
  for i,g in enumerate(CFG['games']):
   if g['game']==args.game:render_game(i,g)
 else:
  intro=render_card();outro=render_card(True)
  with ThreadPoolExecutor(max_workers=2)as pool:
   fs=[pool.submit(render_game,i,g)for i,g in enumerate(CFG['games'])]
   for f in as_completed(fs):f.result()
 segments=[intro]+[WORK/f'game-{i:02}.mkv'for i in range(len(CFG['games']))]+[outro]
 concat=WORK/'concat.txt';concat.write_text(''.join("file '"+p.as_posix()+"'\n"for p in segments))
 starts=[];t=CFG['intro_seconds']
 for g in CFG['games']:
  dur=round(sum(c['duration']for c in g['clips']),3);starts.append(dict(game=g['game'],title=g['title'].replace('\n',' '),start=round(t,3),duration=dur));t+=dur
 metadata=WORK/'chapters.txt';metadata.write_text(';FFMETADATA1\ntitle=Mario In - 15 Game Showcase\nartist=Mario In\n'+''.join('[CHAPTER]\nTIMEBASE=1/1000\nSTART='+str(round(s['start']*1000))+'\nEND='+str(round((s['start']+s['duration'])*1000))+'\ntitle='+s['title']+'\n'for s in starts))
 video=MEDIA/'Mario In - Trailer.mp4'
 run(['ffmpeg','-hide_banner','-y','-f','concat','-safe','0','-i',str(concat),'-i',str(metadata),'-map','0:v','-map','0:a','-map_metadata','1','-map_chapters','1','-c:v','copy','-c:a','aac','-ar','48000','-b:a','192k','-movflags','+faststart',str(video)],WORK/'master-encode.log')
 (MEDIA/'trailer-poster.png').write_bytes((WORK/'intro.png').read_bytes())
 (MEDIA/'trailer-edit.json').write_text(json.dumps(dict(**CFG,chapters=starts),indent=2)+'\n')
 print('TRAILER '+str(video),flush=True)
if __name__=='__main__':main()
