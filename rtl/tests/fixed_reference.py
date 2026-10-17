"""Independent Python integer reference for the provisional complete RTL.

Emits the expected committed scratch-write stream, including reused banks.
This is a bit-exact implementation check, not accuracy validation against float.
"""
from pathlib import Path
import json,math,random
ROOT=Path(__file__).resolve().parents[2]
def rne_div(x,n):
    q,r=divmod(x,n)
    return q+int(2*r>n or (2*r==n and q%2))
def rne(x,bits):return rne_div(x,1<<bits)
def act(x,bits=0):return min(32767,max(-32768,rne(x,bits)))
def inv(n):return rne_div(1<<32,n)
def inverse_root(v,frac=72):
    q=math.isqrt((1<<frac)//v)
    midpoint=v*(2*q+1)**2
    return q+int(midpoint<(1<<(frac+2)) or (midpoint==(1<<(frac+2)) and q%2))
def exp(x):
    if x<-(16<<20):return 0
    coefficients=[rne_div(1<<48,math.factorial(k)) for k in range(8)]
    u=x<<23;p=coefficients[-1]
    for coefficient in reversed(coefficients[:-1]):p=rne(p*u,48)+coefficient
    for _ in range(5):p=rne(p*p,48)
    return rne(p,26)
def gelu_wide(x):
    if x< -6144:return 0
    if x>6144:return x<<12
    square=x*x;term=rne(7359186146747302452*square,20);total=term
    for k in range(1,58):
        term=rne_div(-term*square*(2*k-1),(2*k*(2*k+1))<<20)
        total+=term
    return rne(total+(x<<53),42)
def gelu(x):return gelu_wide(x)

class Reference:
    def __init__(self,shape,parameters,features,mask):
        self.F,self.M,self.N,self.D,self.H,self.K=shape
        self.L=self.M*self.N; self.d=self.D//self.H
        self.params=parameters;self.mask=mask;self.events=[]
        self.banks={b:[] for b in range(18)}
        self.banks[1]=features[:];self.banks[2]=mask[:]
    def write(self,b,i,v):
        a=self.banks[b]
        if len(a)<=i:a.extend([0]*(i+1-len(a)))
        a[i]=v;self.events.append([b,i,v & ((1<<(48 if b==13 else 32 if b==11 else 24 if b in (14,15) else 16))-1)])
    def linear(self,src,base,dst,target,I,O,w,b):
        for o in range(O):
            shift=22 if src==11 else 10
            result=(self.params[b+o]<<shift)+sum(self.banks[src][base+i]*self.params[w+o*I+i] for i in range(I))
            value=act(result,shift)
            self.write(dst,target+o,value<<12 if dst==11 else value)
    def norm(self,src,base,dst,target,length,g,b):
        x=self.banks[src][base:base+length]
        mean=rne_div(sum(x)<<10,length)
        squares=sum(((v<<10)-mean)**2 for v in x)
        variance=rne_div(squares,length<<8)+42950
        scale=inverse_root(variance)
        for i,v in enumerate(x):
            normalized=rne(((v<<10)-mean)*scale,20)
            self.write(dst,target+i,act(normalized*self.params[g+i]+(self.params[b+i]<<20),20))
    def run(self):
        F,M,N,D,H,K,L,d=self.F,self.M,self.N,self.D,self.H,self.K,self.L,self.d
        embed=2*F+D*F+3*D;read=embed+N*D;first=read+M*D;region=12*D*D+13*D
        for t in range(L):
            for i in range(F):self.write(10,i,self.banks[1][t*F+i])
            self.norm(10,0,10,0,F,0,F)
            self.linear(10,0,12,0,F,D,2*F,2*F+D*F)
            self.norm(12,0,12,0,D,2*F+D*F+D,2*F+D*F+2*D)
            for i in range(D):self.write(3,t*D+i,self.banks[12][i])
        for m in range(M):
            for n in range(N):
                for i in range(D):
                    address=(m*N+n)*D+i
                    self.write(3,address,act(act(self.banks[3][address]+self.params[embed+n*D+i])+self.params[read+m*D+i]))
        for k in range(K):
            base=first+k*region
            for t in range(L):self.norm(3,t*D,4,t*D,D,base,base+D)
            for p in range(3):
                for t in range(L):self.linear(4,t*D,5+p,t*D,D,D,base+(4+p)*D+p*D*D,base+(4+p)*D+(p+1)*D*D)
            scale=inverse_root(d,60)
            for h in range(H):
                for q in range(L):
                    scores=[]
                    for key in range(L):
                        score=rne(sum(self.banks[5][q*D+h*d+r]*self.banks[6][key*D+h*d+r] for r in range(d))*scale,30)
                        scores.append(score);self.write(13,key,score)
                    if self.mask[q]:probabilities=[rne_div(1<<22,L)]*L
                    else:
                        maximum=max(scores);exps=[exp(s-maximum) for s in scores]
                        for j,e in enumerate(exps):self.write(14,j,e)
                        inverse=rne_div(1<<54,sum(exps));probabilities=[rne(e*inverse,32) for e in exps]
                    for j,p in enumerate(probabilities):self.write(15,j,p)
                    for r in range(d):self.write(8,q*D+h*d+r,act(sum(probabilities[j]*self.banks[7][j*D+h*d+r] for j in range(L)),22))
            for t in range(L):self.linear(8,t*D,9,t*D,D,D,base+7*D+3*D*D,base+7*D+4*D*D)
            for t in range(L):
                for i in range(D):self.write(3,t*D+i,act(self.banks[3][t*D+i]+self.banks[9][t*D+i]))
            for t in range(L):self.norm(3,t*D,4,t*D,D,base+2*D,base+3*D)
            for t in range(L):
                self.linear(4,t*D,11,0,D,4*D,base+8*D+4*D*D,base+8*D+8*D*D)
                for j in range(4*D):self.write(11,j,gelu(self.banks[11][j]>>12))
                self.linear(11,0,12,0,4*D,D,base+12*D+8*D*D,base+12*D+12*D*D)
                for i in range(D):self.write(3,t*D+i,act(self.banks[3][t*D+i]+self.banks[12][i]))
        final=first+K*region
        for t in range(L):self.linear(3,t*D,16,t,D,1,final,final+D)
        for n in range(N):
            values=[self.banks[16][m*N+n] for m in range(M) if not self.mask[m*N+n]]
            if not values:return {'code':1,'position':n,'outputs':[],'events':self.events}
            self.write(17,n,act(sum(values)*inv(len(values)),32))
        return {'code':0,'position':0,'outputs':self.banks[17][:],'events':self.events}

def fixtures(shape):
    F,M,N,D,H,K=shape;L=M*N;embed=2*F+D*F+3*D;first=embed+N*D+M*D;region=12*D*D+13*D
    randomizer=random.Random(9127)
    parameters=[randomizer.randrange(-600,601) for _ in range(first+K*region+D+1)]
    for g,length in [(0,F),(2*F+D*F+D,D)]+[(first+k*region+o,D) for k in range(K) for o in (0,2*D)]:
        parameters[g:g+length]=[1024+randomizer.randrange(-128,129) for _ in range(length)]
    features=[randomizer.randrange(-2048,2049) for _ in range(L*F)]
    masks=[[0]*L,[int(t%3==1) for t in range(L)],[int(t%N==N-1) for t in range(L)],[1]*L]
    return {'shape':shape,'parameters':parameters,'features':features,'frames':[
        {'mask':mask,**Reference(shape,parameters,features,mask).run()} for mask in masks]}
def precision_fixture():
    # Force every FFN preactivation to exactly1.0; a large but legal W2 weight
    # makes an accidental F10 activation truncation visible in the next linear.
    shape=(2,1,1,2,1,1);fixture=fixtures(shape);F,M,N,D,H,K=shape
    first=2*F+D*F+3*D+N*D+M*D
    w1=first+8*D+4*D*D;b1=first+8*D+8*D*D
    w2=first+12*D+8*D*D;b2=first+12*D+12*D*D
    p=fixture['parameters'];p[w1:w1+4*D*D]=[0]*(4*D*D)
    p[b1:b1+4*D]=[1024]*(4*D);p[w2:w2+4*D*D]=[0]*(4*D*D)
    p[w2]=32767;p[w2+4*D]=-32768;p[b2:b2+D]=[0]*D
    fixture['frames']=[{'mask':f['mask'],**Reference(shape,p,fixture['features'],f['mask']).run()}
                       for f in fixture['frames']]
    return fixture
if __name__=='__main__':
    for name,shape in [('single',(1,1,1,1,1,1)),('multi',(2,2,2,2,1,2)),('heads',(2,1,2,3,3,1)),
                       ('precision',(2,1,1,2,1,1))]:
        result=precision_fixture() if name=='precision' else fixtures(shape)
        (ROOT/f'rtl/tests/core-{name}-reference.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
        print(name,[(f['code'],len(f['events']),f['outputs']) for f in result['frames']])
