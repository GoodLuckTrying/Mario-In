"""Check rebuilt outputs against the published patch catalog and exact originals."""
from pathlib import Path
import datetime,hashlib,json
from check_release import apply_ips
ROOT=Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 rows=[]
 for item in json.loads((ROOT/'release/catalog.json').read_text())['patches']:
  game=item['game'];out=ROOT/game/('build'if game=='castlevania'else'dist')
  rom=(out/(item['name']+'.nes')).read_bytes();patch=(ROOT/'release'/item['patch']).read_bytes();rebuilt=(out/item['patch']).read_bytes();base=(Path('C:/nes')/item['base_filename']).read_bytes()
  assert sha(base)==item['base_sha256'],game+' base hash mismatch'
  assert sha(rom)==item['rom_sha256'],game+' rebuild differs from current release'
  assert sha(patch)==item['patch_sha256']and patch==rebuilt,game+' rebuilt IPS differs'
  assert apply_ips(base,patch)==rom,game+' IPS reconstruction mismatch'
  rows.append(dict(game=game,passed=True,rom_sha256=sha(rom),patch_sha256=sha(patch),rebuilt_rom_matches=True,rebuilt_patch_matches=True,ips_round_trip=True))
 report=dict(verified_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),passed=True,checks=rows,scope='Reorganized sources rebuilt with pinned local ROM inputs. These are reproducibility and IPS checks, separate from historical gameplay receipts.')
 (ROOT/'release/source-package-verification.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS',len(rows),'reorganized builds reproduce the current ROMs and IPS patches exactly.')
if __name__=='__main__':main()
