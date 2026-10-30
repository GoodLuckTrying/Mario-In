from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
subprocess.run([sys.executable,str(ROOT/'tools/verify_new_port.py'),'karnov'],cwd=ROOT,check=True)
