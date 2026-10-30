"""Show the verified gait using tracked crops of actual Mesen frames."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
records=json.loads((ROOT/'build/walk-captures.json').read_text())
groups={direction:[r for r in records if r['direction']==direction]for direction in ['down','up']}
def crop(record):
 im=Image.open(ROOT/'build'/(record['name']+'.png')).convert('RGB');x,y=record['x'],record['y']
 return im.crop((x-4,y-4,x+20,y+20))
frames=[]
for n in range(min(len(group)for group in groups.values())):
 out=Image.new('RGB',(320,204),(247,216,165));draw=ImageDraw.Draw(out)
 for col,direction in enumerate(['down','up']):
  tile=crop(groups[direction][n]);out.paste(tile.resize((144,144),Image.Resampling.NEAREST),(col*160+8,0))
  draw.text((col*160+8,147),direction.upper(),fill=(60,32,16));out.paste(tile,(col*160+68,171))
 frames.append(out)
frames[0].save(ROOT/'build/mario-vertical-walking.gif',save_all=True,append_images=frames[1:],duration=34,loop=0,disposal=2,optimize=False)
out=Image.new('RGB',(640,180),(247,216,165));draw=ImageDraw.Draw(out)
for i,(direction,index)in enumerate([('down',0),('down',3),('up',0),('up',3)]):
 tile=crop(groups[direction][index]);out.paste(tile.resize((144,144),Image.Resampling.NEAREST),(i*160+8,0))
 draw.text((i*160+8,150),direction.upper()+' STEP '+str(index//3+1),fill=(60,32,16))
out.save(ROOT/'build/mario-walking-in-game.png')
