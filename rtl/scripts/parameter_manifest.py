"""Generate the core's canonical parameter/bank manifest for supplied dimensions.

Optional tensor JSON contains signed raw Q10 integers (flat or nested arrays).
It must supply exactly the manifest's tensor names; no trained model is selected.
"""
from pathlib import Path
import argparse,hashlib,json,math
parser=argparse.ArgumentParser(description=__doc__)
for dim in ('f','m','n','d','h','k'):parser.add_argument('--'+dim,type=int,required=True)
parser.add_argument('--out',type=Path,required=True)
parser.add_argument('--tensor-json',type=Path)
parser.add_argument('--image',type=Path)
args=parser.parse_args()
F,M,N,D,H,K=(getattr(args,x) for x in ('f','m','n','d','h','k'))
if not (1<=F<=65535 and 1<=M<=65535 and 1<=N<=65535 and M*N<=65535 and
        1<=D<=16383 and 1<=H<=D and D%H==0 and 1<=K<=65535):parser.error('dimensions violate RTL count/head limits')
def nearest(n,d):
    q,r=divmod(n,d);return q+int(2*r>d or (2*r==d and q%2))
def scale(n):
    q=math.isqrt((1<<60)//n);midpoint=n*(2*q+1)**2
    return q+int(midpoint<(1<<62) or (midpoint==(1<<62) and q%2))
tensors=[];cursor=0
def tensor(name,shape):
    global cursor
    size=math.prod(shape)
    tensors.append({'name':name,'shape':shape,'base':cursor,'words':size,'format':'signed16/Q10','layout':'row-major W[out,in]'})
    cursor+=size
tensor('embedding.norm_f.gamma',[F]);tensor('embedding.norm_f.beta',[F])
tensor('embedding.linear.weight',[D,F]);tensor('embedding.linear.bias',[D])
tensor('embedding.norm_d.gamma',[D]);tensor('embedding.norm_d.beta',[D])
tensor('position',[N,D]);tensor('read_embedding',[M,D]);first_layer=cursor
for layer in range(K):
    prefix=f'layer.{layer}'
    for norm in ('ln1','ln2'):
        for field in ('gamma','beta'):tensor(f'{prefix}.{norm}.{field}',[D])
    for projection in ('q','key','value','out'):
        tensor(f'{prefix}.{projection}.weight',[D,D]);tensor(f'{prefix}.{projection}.bias',[D])
    tensor(f'{prefix}.ffn1.weight',[4*D,D]);tensor(f'{prefix}.ffn1.bias',[4*D])
    tensor(f'{prefix}.ffn2.weight',[D,4*D]);tensor(f'{prefix}.ffn2.bias',[D])
tensor('final.weight',[1,D]);tensor('final.bias',[1])
assert cursor==2*F+D*F+3*D+N*D+M*D+K*(12*D*D+13*D)+D+1
lengths=[cursor,M*N*F,M*N]+[M*N*D]*7+[F,4*D,D,M*N,M*N,M*N,M*N,N]
if any(v>1<<32 for v in lengths):parser.error('bank or parameter image exceeds 32-bit native-element address space')
names=['PARAM','FEATURE','MASK','X','U','Q','KEY','VALUE','Z','ATTN_OUT','TOKEN','FFN_HIDDEN','VECTOR','SCORE','EXP','PROB','LOGIT','OUTPUT']
widths=[1 if i==2 else 48 if i==13 else 24 if i in (14,15) else 16 for i in range(18)]
manifest={'status':'provisional numerical RTL configuration; model selection and numerical validation remain external',
 'dimensions':dict(F=F,M=M,N=N,D=D,H=H,K=K,L=M*N,head_dimension=D//H),
 'parameter_words':cursor,'first_layer_base':first_layer,'layer_stride':12*D*D+13*D,
 'static_mask_supported':False,'rounding':'nearest, ties to even',
 'nonlinear_method':'Taylor arithmetic; see RTL-TAYLOR-CHECKPOINT.md',
 'primitive_formats':{'exp_response':'unsigned24/F22','gelu_request':'signed16/F10',
   'gelu_response':'signed32/F22','ffn_hidden_storage':'signed16/F10'},
 'constants':{'inverse_f_Q32':nearest(1<<32,F),'inverse_d_Q32':nearest(1<<32,D),
   'score_scale_Q30':scale(D//H),'uniform_Q22':nearest(1<<22,M*N),'epsilon_Q32':42950},
 'tensors':tensors,'banks':[{'id':i,'name':name,'elements':lengths[i],'width':widths[i],'bits':lengths[i]*widths[i]}
                          for i,name in enumerate(names)],'total_storage_bits':sum(v*w for v,w in zip(lengths,widths))}
if bool(args.tensor_json)!=bool(args.image):parser.error('--tensor-json and --image must be supplied together')
if args.tensor_json:
    values=json.loads(args.tensor_json.read_text());expected={t['name'] for t in tensors}
    if set(values)!=expected:parser.error(f'tensor names mismatch: missing {expected-set(values)}, extra {set(values)-expected}')
    def flatten(value):
        if isinstance(value,list):
            for item in value:yield from flatten(item)
        else:yield value
    image=[]
    for t in tensors:
        data=list(flatten(values[t['name']]))
        if len(data)!=t['words'] or any(type(v)!=int or not -32768<=v<=32767 for v in data):
            parser.error('invalid raw Q10 values/length for '+t['name'])
        raw=b''.join((v&65535).to_bytes(2,'little') for v in data)
        t['sha256_le16']=hashlib.sha256(raw).hexdigest();image+=data
    args.image.parent.mkdir(parents=True,exist_ok=True)
    args.image.write_text(''.join(f'{v&65535:04x}\n' for v in image),encoding='ascii')
    manifest['image']={'path':str(args.image),'sha256_file':hashlib.sha256(args.image.read_bytes()).hexdigest(),
      'host_order':'one native 16-bit word per increasing address, wait for write acknowledgment before commit'}
args.out.parent.mkdir(parents=True,exist_ok=True)
args.out.write_text(json.dumps(manifest,indent=2)+'\n')
print(f'{len(tensors)} tensors, {cursor} parameter words, {manifest["total_storage_bits"]} storage bits')
