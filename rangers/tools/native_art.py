from research import rom,ROOT
b=rom[16+5*16384:16+6*16384]
def byte(a):return b[a-0x8000]
def word(lo,hi,i):return byte(lo+i)|byte(hi+i)<<8
def sequence(i):
 p=word(0xB4B6,0xB55F,i);frames=byte(p)&127
 result=set()
 for n in range(frames+1):
  m=byte(p+2+n)
  q=word(0x9C82,0x9DAE,m) if byte(p)&128 else word(0x9B82,0x9CAE,m)
  for t in range(byte(q)+1):result.add(byte(q+2+t*2))
 return result
if __name__=='__main__':
 players=set();other=set()
 for i in range(1,0xA9):
  try:s=sequence(i)
  except IndexError:continue
  if i<=24 or i in [0x29,0x2A,0x99,0x9A,0xA1,0xA5]:players|=s;print(f'{i:02X}',sorted(s))
  else:other|=s
 print('Exclusive player tiles',len(players-other),sorted(players-other))
 print('Shared player tiles',len(players&other),sorted(players&other))
