"""Fetch pinned source submodules and the pinned Windows WLA-DX toolchain."""
from pathlib import Path
import argparse,hashlib,json,subprocess,urllib.request,zipfile
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--skip-submodules',action='store_true');a=p.parse_args()
 lock=json.loads((ROOT/'dependencies.json').read_text())
 if not a.skip_submodules:subprocess.run(['git','submodule','update','--init','--recursive'],cwd=ROOT,check=True)
 for item in lock['submodules']:
  actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT/item['path'],text=True).strip()
  assert actual==item['commit'],item['path']+' is not at its pinned revision'
 tool=lock['wla_dx'];archive=ROOT/'vendor/wla-dx-10.7.zip'
 if not archive.exists()or hashlib.sha256(archive.read_bytes()).hexdigest()!=tool['sha256']:
  print('Downloading WLA-DX '+tool['version'],flush=True)
  with urllib.request.urlopen(tool['url'])as response:data=response.read()
  assert hashlib.sha256(data).hexdigest()==tool['sha256'],'WLA-DX archive hash mismatch'
  archive.write_bytes(data)
 dest=ROOT/'vendor/wla-dx-10.7';dest.mkdir(exist_ok=True)
 with zipfile.ZipFile(archive)as z:
  for name in z.namelist():assert (dest/name).resolve().is_relative_to(dest.resolve()),'Unsafe archive member'
  z.extractall(dest)
 assert (dest/'wla_dx_v10.7_Win64/wla-6502.exe').is_file()
 print('Pinned source dependencies and WLA-DX are ready.')
if __name__=='__main__':main()
