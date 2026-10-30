"""Build a port without installing over the user's playable ROMs."""
from pathlib import Path
import argparse,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def main():
 catalog=json.loads((ROOT/'release/catalog.json').read_text())['patches']
 p=argparse.ArgumentParser();p.add_argument('game',choices=['all']+[x['game']for x in catalog]);a=p.parse_args()
 for item in catalog:
  game=item['game']
  if a.game not in ('all',game):continue
  project=ROOT/game
  (project/'build').mkdir(exist_ok=True)
  (project/'dist').mkdir(exist_ok=True)
  if game=='castlevania':(project/'analysis').mkdir(exist_ok=True)
  commands=[project/'tools/build.py']
  if game in ('contra','tetris'):commands.insert(0,project/'tools/native.py')
  if game=='punchout':commands.insert(0,project/'tools/build_reference.py')
  for script in commands:subprocess.run([sys.executable,str(script)],cwd=project if game=='kidicarus'else ROOT,check=True)
  print('BUILT '+game,flush=True)
if __name__=='__main__':main()
