"""Record every fixture used by the trailer, with native PCM audio and video."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
work=ROOT/'build/trailer';work.mkdir(parents=True,exist_ok=True)
subprocess.run(['gcc','-shared','-O2','-Wall','-Wextra','-Wno-cast-function-type','-o',str(work/'mesen_capture_bridge.dll'),str(ROOT/'tools/trailer/mesen_capture_bridge.c')],check=True)
# WWF's graphics oracle compares against a freshly captured unmodified reference.
subprocess.run([sys.executable,str(ROOT/'tools/port_probe.py'),'wwf',str(ROOT/'wwf/tests/reference_graphics.lua'),'--rom','C:/nes/WWF WrestleMania (USA).nes','--timeout','30'],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
def record(job):
 cmd=[sys.executable,str(ROOT/'tools/trailer/capture_fixture.py'),job['game'],job['fixture']]
 for d in job['defines']:cmd+=['--define',d]
 subprocess.run(cmd,cwd=ROOT,check=True)
with ThreadPoolExecutor(max_workers=2)as pool:
 for result in as_completed([pool.submit(record,j)for j in json.loads((ROOT/'tools/trailer/recordings.json').read_text())]):result.result()
print('All native trailer recordings completed.')
