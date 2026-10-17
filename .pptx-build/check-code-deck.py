from pathlib import Path
import zipfile,xml.etree.ElementTree as E,re,posixpath
root=Path('..');ppt=root/'presentation/BCJRFormer-Architecture-Amit-with-code.pptx'
ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main','p':'http://schemas.openxmlformats.org/presentationml/2006/main'}
def text(el):return '\n'.join(''.join(t.text or '' for t in p.findall('.//a:t',ns)) for p in el.findall('.//a:p',ns))
actual=[];script=['# BCJRFormer architecture with code\n\nSpeaker notes for all 19 slides. Use the diagrams for the main explanation and point out selected lines on the code slides.\n']
with zipfile.ZipFile(ppt) as z:
 for i in range(1,20):
  slide=E.fromstring(z.read(f'ppt/slides/slide{i}.xml'))
  title=text(slide.findall('.//p:sp',ns)[0])
  for sh in slide.findall('.//p:sp',ns):
   prop=sh.find('p:nvSpPr/p:cNvPr',ns)
   if prop is not None and prop.get('name')=='raw-python-excerpt':actual.append(text(sh))
  rels=E.fromstring(z.read(f'ppt/slides/_rels/slide{i}.xml.rels'))
  ref=next(r.get('Target') for r in rels if r.get('Type').endswith('/notesSlide'))
  note=E.fromstring(z.read(ref.lstrip('/') if ref.lstrip('/').startswith('ppt/') else posixpath.normpath('ppt/slides/'+ref)))
  raw=text(note);assert 'WHAT TO SAY' in raw and raw.strip() != 'undefined',(i,raw)
  speech=raw.split('WHAT TO SAY',1)[1].split('SOURCE',1)[0].strip()
  script.append(f'## Slide {i}: {title}\n\n{speech}\n')
expected=[]
src=Path('update-deck.mjs').read_text(encoding='utf-8-sig')
for file,a,b in re.findall(r"\['(bcjrformer.py|modules.py)',(\d+),(\d+)\]",src):
 lines=(root/'BCJRFormer/bcjrformer/models'/file).read_text().splitlines()[int(a)-1:int(b)]
 lines=[s for s in lines if s.strip()];indent=min(len(s)-len(s.lstrip(' ')) for s in lines)
 expected.append('\n'.join(s[indent:] for s in lines))
assert actual==expected,(len(actual),len(expected))
(root/'presentation/BCJRFormer-speaker-notes-with-code.md').write_text('\n'.join(script),encoding='utf-8')
print(f'All 19 slides have speaker notes. All {len(actual)} code excerpts match source. Rehearsal script written.')

