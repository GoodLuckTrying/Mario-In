"""Contact sheets made from actual emulator captures, at integer scales."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
def crop(prefix,name):
 poses=json.loads((ROOT/'build'/f'{prefix}poses.json').read_text());pose=next(p for p in poses if p['name']==name)
 im=Image.open(ROOT/'build'/f'{prefix}{name}.png').convert('RGB');x,y=pose['x'],pose['y']
 return im.crop((x-4,y-4,x+20,y+20))
def sheet(name,entries):
 out=Image.new('RGB',(len(entries)*160,204),(247,216,165));draw=ImageDraw.Draw(out)
 for i,(label,prefix,pose)in enumerate(entries):
  im=crop(prefix,pose);out.paste(im.resize((144,144),Image.Resampling.NEAREST),(i*160+8,0))
  draw.text((i*160+8,147),label,fill=(60,32,16))
  out.paste(im,(i*160+68,171))
 out.save(ROOT/'build'/name)
sheet('mario-in-game-comparison.png',[
 ('PREVIOUS FRONT','previous-','front'),('REDRAWN FRONT','visual-','front'),('REDRAWN BACK','visual-','back'),('LEFT','visual-','left'),('RIGHT','visual-','right')])
sheet('mario-actions-in-game.png',[
 ('FRONT ATTACK','visual-','front-attack'),('BACK ATTACK','visual-','back-attack'),('ONE-HAND LIFT','visual-','lift-one-hand'),('TWO-HAND LIFT','visual-','lift-two-hands')])
sheet('mario-front-back-in-game.png',[
 ('FRONT','visual-','front'),('BACK','visual-','back')])
