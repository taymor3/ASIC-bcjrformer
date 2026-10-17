from pathlib import Path
import json,subprocess,sys
root=Path(__file__).resolve().parents[2];results=[]
for name in ('single','multi','heads'):
    reference=json.loads((root/f'rtl/tests/core-{name}-reference.json').read_text())
    base=root/f'rtl/tests/{name}-manifest.json';image=root/f'rtl/tests/{name}-parameters.hex'
    dims=sum((['--'+d,str(v)] for d,v in zip(('f','m','n','d','h','k'),reference['shape'])),[])
    command=[sys.executable,str(root/'rtl/scripts/parameter_manifest.py'),*dims,'--out',str(base)]
    subprocess.run(command,check=True,cwd=root)
    manifest=json.loads(base.read_text());cursor=0;tensors={}
    for tensor in manifest['tensors']:
        assert tensor['base']==cursor
        tensors[tensor['name']]=reference['parameters'][cursor:cursor+tensor['words']]
        cursor+=tensor['words']
    assert cursor==len(reference['parameters'])==manifest['parameter_words']
    tensor_file=root/f'rtl/tests/{name}-tensor-input.json';tensor_file.write_text(json.dumps(tensors)+'\n')
    subprocess.run(command+['--tensor-json',str(tensor_file),'--image',str(image)],check=True,cwd=root)
    raw=[int(v,16) for v in image.read_text().splitlines()]
    assert raw==[v&65535 for v in reference['parameters']]
    results.append({'shape':name,'words':cursor,'passed':True})
(root/'rtl/tests/manifest-results.json').write_text(json.dumps(results,indent=2)+'\n')
print('3/3 manifest/image round trips passed')
