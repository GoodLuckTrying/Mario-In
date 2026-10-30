from concurrent.futures import ThreadPoolExecutor,as_completed
import hashlib,json,subprocess,sys,time
from build import ROOT,BASE,SMB,SHA,SMBSHA,NAME
def main():
 subprocess.run([sys.executable,str(ROOT/'tools/verify_cpu.py')],check=True)
 jobs=[('new-save-opening','probe',{}),('hardware-directional-art','hardware',{}),('native-enemy','enemy',{}),('pause-inventory','pause',{}),('room-transition','transition',{}),('native-save-reload','save',{})]
 jobs += [('item-'+str(i),'items',{'ITEM':i})for i in [0,1,2,4,5,6,7,8]]
 jobs += [('dungeon-art-'+str(i),'hardware',{'LEVEL':i})for i in range(1,10)]
 jobs += [('native-death-continue','death',{})]
 jobs += [('directional-action-visual-captures','visual',{})]
 jobs += [('vertical-walking','walk',{}),('dungeon-vertical-walking','walk',{'LEVEL':1})]
 logs=ROOT/'build/verification';logs.mkdir(exist_ok=True)
 def replay(job):
  name,script,defs=job;start=time.time()
  args=[sys.executable,str(ROOT.parent/'tools/port_probe.py'),'zelda',str(ROOT/'tests'/f'{script}.lua'),'--rom',str(ROOT/'dist'/f'{NAME}.nes'),'--timeout','40']
  for k,v in defs.items():args+=['--define',k+'='+repr(v)]
  try:
   p=subprocess.run(args,capture_output=True,text=True,timeout=50);out=p.stdout+p.stderr;ok=p.returncode==0 and 'PASS 'in out and 'FAIL 'not in out
  except Exception as e:out=str(e);ok=False
  (logs/(name+'.log')).write_text(out)
  return {'name':name,'passed':ok,'seconds':round(time.time()-start,2)}
 checks=[]
 with ThreadPoolExecutor(max_workers=4)as pool:
  for f in as_completed([pool.submit(replay,j)for j in jobs]):
   item=f.result();checks.append(item);print(item['name'],'PASS'if item['passed']else'FAIL',flush=True)
 assert all(c['passed']for c in checks),'Inspect zelda/build/verification'
 rom=(ROOT/'dist'/f'{NAME}.nes').read_bytes();old=BASE.read_bytes();meta=json.loads((ROOT/'build/manifest.json').read_text());sha=hashlib.sha256(rom).hexdigest()
 assert sha==meta['output_sha256']and hashlib.sha256(old).hexdigest()==SHA and hashlib.sha256(SMB.read_bytes()).hexdigest()==SMBSHA
 assert (ROOT/'build/native.nes').read_bytes()==old
 common=(ROOT/'build/source/bin/dat/CommonSpritePatterns.dat').read_bytes()
 allowed=set(range(28))|set(range(0x54,0x56))|set(range(0x58,0x62))
 for tile in range(112):
  if tile not in allowed:assert common[tile*16:(tile+1)*16]==old[16+32895+tile*16:16+32895+(tile+1)*16]
 demo=(ROOT/'build/source/bin/dat/DemoSpritePatterns.dat').read_bytes()
 for i,value in enumerate(demo):
  if not 0x80<=i<0xa0:assert value==old[16+19892+i]
 patch=(ROOT/'dist'/f'{NAME}.ips').read_bytes();assert patch[:5]==b'PATCH';i=5;out=bytearray(old)
 while patch[i:i+3]!=b'EOF':
  a=int.from_bytes(patch[i:i+3],'big');n=int.from_bytes(patch[i+3:i+5],'big');i+=5;assert n
  if a+n>len(out):out.extend(bytes(a+n-len(out)))
  out[a:a+n]=patch[i:i+n];i+=n
 assert out==rom
 checks.append({'name':'unchanged originals, exact native disassembly reproduction and IPS reconstruction','passed':True})
 checks.append({'name':'all non-player common and demo/weapon CHR bytes are preserved','passed':True})
 sys.path.insert(0,str(ROOT.parent/'tools'))
 from directional_art import pose as directional_pose,source_info
 assert source_info()['sha256']=='ae395caae88ade3c2d6b3f2503c45e9f2b92ff5c84020d3f1891277a6bcf2a4d'
 for view,tiles,state in [('front',[8,10],'idle'),('back',[12,14],'idle'),('front',[0x5c,0x5e],'walk'),('back',[0x54,0x60],'walk'),('front',[20,22],'throw'),('back',[24,26],'throw')]:
  art=directional_pose('small',view,state)
  for y in range(16):
   for x in range(16):
    tile=tiles[x//8]+y//8;offset=tile*16+y%8;bit=7-x%8
    pixel=((common[offset]>>bit)&1)|(((common[offset+8]>>bit)&1)<<1)
    assert pixel==art[y][x],(view,state,'source pixels',x,y)
 checks.append({'name':'front/back idle, walking and throwing art matches the newly supplied sheet pixel-for-pixel','passed':True})
 cpu=json.loads((ROOT/'build/cpu-verification.json').read_text());assert cpu['rom_sha256']==sha;checks+=cpu['checks']
 receipt={'rom_sha256':sha,'passed':True,'checks':sorted(checks,key=lambda x:x['name']),'originals_unchanged':True,'ips_reconstructs_rom':True,'limits':['Mechanics fixtures seed inventory or actors. This is not a full unassisted campaign or physical NES playthrough.']}
 (ROOT/'dist/verification.json').write_text(json.dumps(receipt,indent=2));print('All',len(checks),'checks passed; originals unchanged.',flush=True)
if __name__=='__main__':main()
