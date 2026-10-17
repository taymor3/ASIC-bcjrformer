from pathlib import Path
import json,math,random
from fixed_reference import rne_div,inverse_root,exp,gelu_wide,act
root=Path(__file__).resolve().parents[2];vectors=[];rng=random.Random(7421)
def add(mode,value,result,error=0,flags=None):
    vectors.append({'mode':mode,'req':str(value%(1<<128)),'rsp':str(result),'error':error,'flags':flags})
for mode in (0,1,2):
    samples=[(-32768,-32768,0),(32767,32767,(1<<47)-1),(-32768,32767,-(1<<47)),(1,-1,(1<<63)-1)]
    samples += [(rng.randrange(-(1<<15),1<<15) if mode==0 else rng.randrange(1<<24) if mode==1 else rng.randrange(-(1<<31),1<<31),rng.randrange(-(1<<15),1<<15),rng.randrange(-(1<<40),1<<40)) for _ in range(100)]
    for a,b,c in samples:
        aa=a&((1<<16)-1) if mode==0 else a&((1<<24)-1) if mode==1 else a&0xffffffff
        request=(mode<<112)|(aa<<80)|((b&65535)<<64)|(c&((1<<64)-1))
        av=a if mode in (0,2) else aa
        result=c+av*b;width=48 if mode==0 else 64
        error=int(not -(1<<(width-1))<=result<(1<<(width-1)) or (mode==0 and not -(1<<47)<=c<(1<<47)))
        add(0,request,result&((1<<64)-1),error,4 if error else 0)
add(0,(1<<96),0,1,8) # nonzero unused high A bits in signed mode
add(0,(16<<80)|(16<<64)|((-(1<<47)-1)&((1<<64)-1)),0,1,4) # invalid accumulator cancelled into range
add(0,(1<<112)|(1<<104),0,1,8) # nonzero unused A bits in probability mode
add(0,(3<<112),0,1,8) # reserved dot mode
# Signed wide activation and accumulator boundaries, including negative products.
for a,b,c in [(-(1<<31),-32768,0),((1<<31)-1,32767,0),(-1,1024,0),
              (1,1,(1<<63)-1),(-1,1,-(1<<63))]:
    result=c+a*b;error=int(not -(1<<63)<=result<(1<<63))
    request=(2<<112)|((a&0xffffffff)<<80)|((b&65535)<<64)|(c&((1<<64)-1))
    add(0,request,result&((1<<64)-1),error,4 if error else 0)
for x in [1,0,-1,-1023,-1024,-(16<<20),-(16<<20)-1]+[rng.randrange(-(16<<20),1) for _ in range(100)]:
    add(1,x,0 if x>0 else exp(x),int(x>0),4 if x>0 else int(x!=0))
for d in [0,(1<<22)-1,1<<22,65535<<22,(65535<<22)+1]+[rng.randrange(1<<22,(65535<<22)+1) for _ in range(100)]:
    error=int(not 1<<22<=d<=65535<<22)
    add(2,d,0 if error else rne_div(1<<54,d),error,4 if error else int((1<<54)%d!=0))
for v in [0,42949,42950,1<<32,4096<<32,(4096<<32)+1]+[rng.randrange(42950,(4096<<32)+1) for _ in range(100)]:
    error=int(not 42950<=v<=4096<<32)
    result=0 if error else inverse_root(v)
    q=0 if error else math.isqrt((1<<72)//v)
    add(3,v,result,error,4 if error else int(v*q*q!=(1<<72)))
for x in [-32768,-8193,-8192,-6145,-6144,-6143,-1,0,1,6143,6144,6145,8192,8193,32767]+[rng.randrange(-32768,32768) for _ in range(200)]:
    add(4,x,gelu_wide(x)&0xffffffff,0,int(x!=0))
for a,b in [(-32768,-1),(32767,1),(-32768,32767),(0,0)]+[(rng.randrange(-32768,32768),rng.randrange(-32768,32768)) for _ in range(100)]:
    add(5,((a&65535)<<16)|(b&65535),act(a+b)&65535,0,2 if not -32768<=a+b<=32767 else 0)
(root/'rtl/tests/arithmetic-vectors.json').write_text(json.dumps(vectors,separators=(',',':'))+'\n')
print(len(vectors),'arithmetic vectors')
