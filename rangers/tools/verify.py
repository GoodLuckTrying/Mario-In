from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,hashlib,json,subprocess,sys,time,zlib
ROOT=Path(__file__).resolve().parents[1]
NAME='Mario and Luigi in Rescue Rangers'
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--reuse-passed',action='store_true');options=parser.parse_args()
 prior=json.loads((ROOT/'dist/verification.json').read_text()) if options.reuse_passed else {}
 manifest=json.loads((ROOT/'build/manifest.json').read_text());rom=(ROOT/'dist'/f'{NAME}.nes').read_bytes()
 passed_before={c['name'] for c in prior.get('checks',[]) if c['passed']} if prior.get('rom_sha256')==manifest['output_sha256'] else set()
 file_crc=f'File CRC32: 0x{zlib.crc32(rom):08X}'
 checks=[];start=time.time()
 def record(name,ok,detail):
  checks.append({'name':name,'passed':ok,'detail':detail});print(('PASS ' if ok else 'FAIL ')+name,flush=True)
 original=Path("C:/nes/Chip 'n Dale - Rescue Rangers (USA).nes").read_bytes()
 patch=(ROOT/'dist'/f'{NAME}.ips').read_bytes();rebuilt=bytearray(original);i=5
 while patch[i:i+3]!=b'EOF':
  offset=int.from_bytes(patch[i:i+3],'big');n=int.from_bytes(patch[i+3:i+5],'big');i+=5
  if n:data=patch[i:i+n];i+=n
  else:
   count=int.from_bytes(patch[i:i+2],'big');data=patch[i+2:i+3]*count;i+=3
  if len(rebuilt)<offset+len(data):rebuilt.extend(bytes(offset+len(data)-len(rebuilt)))
  rebuilt[offset:offset+len(data)]=data
 record('original hashes and exact IPS reconstruction',bytes(rebuilt)==rom and hashlib.sha256(original).hexdigest()==manifest['base_sha256'] and hashlib.sha256(rom).hexdigest()==manifest['output_sha256'],'Separate output ROM; original byte hash and complete patch round trip')
 result=subprocess.run([sys.executable,str(ROOT/'tools/verify_physics.py')],capture_output=True,text=True)
 record('SMB1 differential movement',result.returncode==0,result.stdout+result.stderr)
 result=subprocess.run([sys.executable,str(ROOT/'tools/verify_bounds.py')],capture_output=True,text=True)
 record('viewport and native corner terrain bounds',result.returncode==0,result.stdout+result.stderr)
 result=subprocess.run([sys.executable,str(ROOT/'tools/verify_horizontal.py')],capture_output=True,text=True)
 record('horizontal full-speed collision boundaries',result.returncode==0,result.stdout+result.stderr)
 result=subprocess.run([sys.executable,str(ROOT.parent/'tools/audit_all_physics.py'),'--candidate','--game','rangers','--require-match'],capture_output=True,text=True)
 record('expanded SMB1 source differential movement',result.returncode==0,result.stdout+result.stderr)
 jobs=[]
 def job(script,**defines):
  title=script+' '+','.join(f'{k}={v}' for k,v in defines.items());args=[sys.executable,str(ROOT/'tools/run_mesen.py'),str(ROOT/'tests'/f'{script}.lua')]
  for k,v in defines.items():args+=['--define',k+'='+('true' if v is True else 'false' if v is False else str(v) if isinstance(v,int) else "'"+v+"'")]
  jobs.append((title,args))
 job('play')
 job('boxes')
 job('upperroute')
 for power in range(3):
  for coop in [False,True]:job('performance',POWER=power,COOP=coop)
 for coop in [False,True]:job('rendercapacity',COOP=coop)
 for stage in range(11):job('palettes',STAGE=stage)
 job('palettes',COOP=True)
 for stage in range(11):job('stages',STAGE=stage)
 for p in range(2):
  for power in [1,2]:job('physics-audit',PLAYER=p,POWER=power)
  job('collectibles',PLAYER=p)
  for power in range(3):
   for coop in [False,True]:
    for carry in [False,True]:
     for run in [False,True]:job('doorway',PLAYER=p,POWER=power,COOP=coop,CARRY=carry,RUN=run)
   for upper in [False,True]:
    for left in [False,True]:
     for moving in [False,True]:job('mapboxes',PLAYER=p,POWER=power,UPPER=upper,LEFT=left,MOVING=moving)
   job('corner',PLAYER=p,POWER=power)
   job('corner',PLAYER=p,POWER=power,FIXTURE=True)
   for option in ['MOVING','EDGE','AIR']:job('carry',PLAYER=p,POWER=power,**{option:True})
   for up in [False,True]:job('carry',PLAYER=p,POWER=power,UP=up)
   job('electricterrain',PLAYER=p,POWER=power)
   for kind in [0x20,0x21,0x22]:job('combat',PLAYER=p,POWER=power,MODE='hazard',HAZARD_KIND=kind)
   for mode in ['stomp','damage','overhead']:job('combat',PLAYER=p,POWER=power,MODE=mode)
   job('combat',PLAYER=p,POWER=power,MODE='stomp',PAIR=True)
   for mode in ['drop','landing','wall','ceiling','object']:job('terrain',PLAYER=p,POWER=power,MODE=mode)
  for obj in [0x22,0x24,0x25]:
   for up in [False,True]:job('carry',PLAYER=p,OBJECT=obj,UP=up,POWER=1)
  for power in [0,2]:job('coop',CARRIER=p,POWER=power)
  job('combat',PLAYER=p,MODE='damage',RETRY=True)
  for mode in ['hit','limit']:job('fire',PLAYER=p,MODE=mode)
  job('boss',PLAYER=p)
 job('fire',MODE='limit',COOP=True)
 for room in [1,2]:job('rooms',ROOM=room)
 logs=ROOT/'build/logs';logs.mkdir(exist_ok=True)
 def execute(job):
  title,args=job
  path=logs/(title.replace(' ','_').replace(',','_').replace('=','-')+'.txt')
  if title in passed_before and path.exists():
   output=path.read_text()
   dependencies=[Path(args[1]),Path(args[2]),ROOT/'build/manifest.json',ROOT/'dist'/f'{NAME}.nes']
   if file_crc in output and all(item.stat().st_mtime_ns<=path.stat().st_mtime_ns for item in dependencies):
    return title,True,'Reused unchanged script and exact-ROM passing log: '+str(path)
  try:
   result=subprocess.run(args,capture_output=True,text=True,timeout=45)
   output=result.stdout+result.stderr
   (logs/(title.replace(' ','_').replace(',','_').replace('=','-')+'.txt')).write_text(output)
   return title,result.returncode==0 and 'PASS ' in output,output[-1800:]
  except Exception as ex:return title,False,str(ex)
 with ThreadPoolExecutor(max_workers=4) as pool:
  for future in as_completed([pool.submit(execute,item) for item in jobs]):record(*future.result())
 receipt={'rom_sha256':manifest['output_sha256'],'checks':checks,'passed':sum(x['passed'] for x in checks),'total':len(checks),'elapsed_seconds':round(time.time()-start,1),'coverage_limit':'Fixtures seed RAM to isolate mechanics. Stage openings and room/boss fixtures are not a full campaign clear.'}
 (ROOT/'dist/verification.json').write_text(json.dumps(receipt,indent=2))
 print(f"{receipt['passed']}/{receipt['total']} checks passed in {receipt['elapsed_seconds']}s")
 assert all(x['passed'] for x in checks),'Inspect rangers/build/logs and verification.json'
if __name__=='__main__':main()
