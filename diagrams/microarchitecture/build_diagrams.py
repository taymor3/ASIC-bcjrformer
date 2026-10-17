"""Generate editable SVG and diagrams.net sources. Python standard library only."""
from pathlib import Path
from html import escape
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parent
BG, PANEL, BORDER = '#0b111b', '#111d2c', '#31455d'
WHITE, MUTED = '#eff5ff', '#a9bbd1'
CYAN, GREEN, GOLD, PURPLE = '#64d8ef', '#77e3b0', '#ffc879', '#beabff'


class Canvas:
    def __init__(self, width, height, title, desc):
        self.w, self.h, self.parts, self.items = width, height, [], []
        self.title, self.desc = title, desc

    def rect(self, x, y, w, h, fill=PANEL, stroke=BORDER, radius=12):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}"/>')
        self.items.append(('rect', x, y, w, h, fill, stroke, radius))

    def text(self, x, y, text, size=18, color=WHITE, bold=False, anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" font-weight="{700 if bold else 400}" text-anchor="{anchor}">{escape(text)}</text>')
        self.items.append(('text', x, y, text, size, color, bold, anchor))

    def lines(self, x, y, lines, size=18, color=MUTED, step=27):
        for i, line in enumerate(lines):
            self.text(x, y+i*step, line, size, color)

    def wire(self, pts, color=CYAN, dashed=False, both=False, arrow=True):
        d = 'M'+' L'.join(f'{x},{y}' for x, y in pts)
        dash = ' stroke-dasharray="7 6"' if dashed else ''
        marker = f' marker-end="url(#{color[1:]})"' if arrow else ''
        start = f' marker-start="url(#{color[1:]}-start)"' if both else ''
        self.parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="2"{dash}{marker}{start}/>')
        self.items.append(('wire', pts, color, dashed, both, arrow))

    def box(self, x, y, w, h, title, subtitle=None, color=CYAN):
        self.rect(x, y, w, h)
        self.rect(x, y, 4, h, color, color, 2)
        self.text(x+20, y+32, title, 22, WHITE, True)
        if subtitle:
            self.lines(x+20, y+59, subtitle, 17, MUTED, 25)

    def header(self, eyebrow, title, subtitle):
        self.text(50, 42, eyebrow, 15, CYAN, True)
        self.text(50, 88, title, 34, WHITE, True)
        self.text(50, 121, subtitle, 18, MUTED)

    def save(self, name):
        defs = []
        for c in [CYAN, GREEN, GOLD, PURPLE, MUTED]:
            defs.append(f'<marker id="{c[1:]}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L10,5 L0,10 Z" fill="{c}"/></marker>')
            defs.append(f'<marker id="{c[1:]}-start" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 Z" fill="{c}"/></marker>')
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" role="img" aria-labelledby="title desc"><title id="title">{escape(self.title)}</title><desc id="desc">{escape(self.desc)}</desc><defs>{"".join(defs)}</defs><rect width="100%" height="100%" fill="{BG}"/><g font-family="Arial, Helvetica, sans-serif">{"".join(self.parts)}</g></svg>'
        (OUT / f'{name}.svg').write_text(svg, encoding='utf-8')
        self.drawio(name)

    def drawio(self, name):
        doc = ET.Element('mxfile', host='app.diagrams.net', version='24.7.17')
        page = ET.SubElement(doc, 'diagram', name=self.title, id=name)
        model = ET.SubElement(page, 'mxGraphModel', dx=str(self.w), dy=str(self.h), grid='1', gridSize='10', page='1', pageScale='1', pageWidth=str(self.w), pageHeight=str(self.h), background=BG)
        root = ET.SubElement(model, 'root')
        ET.SubElement(root, 'mxCell', id='0')
        ET.SubElement(root, 'mxCell', id='1', parent='0')
        for i, item in enumerate(self.items, 2):
            if item[0] == 'rect':
                _, x, y, w, h, fill, stroke, radius = item
                cell = ET.SubElement(root, 'mxCell', id=str(i), value='', style=f'rounded={int(radius>0)};arcSize=10;fillColor={fill};strokeColor={stroke};', vertex='1', parent='1')
                ET.SubElement(cell, 'mxGeometry', x=str(x), y=str(y), width=str(w), height=str(h), **{'as':'geometry'})
            elif item[0] == 'text':
                _, x, y, text, size, color, bold, anchor = item
                width = max(100, len(text)*size*0.62+15)
                left = x-width/2 if anchor == 'middle' else x
                cell = ET.SubElement(root, 'mxCell', id=str(i), value=text, style=f'text;html=0;align={"center" if anchor=="middle" else "left"};verticalAlign=middle;whiteSpace=wrap;rounded=0;strokeColor=none;fillColor=none;fontFamily=Arial;fontSize={size};fontColor={color};fontStyle={int(bold)};spacing=0;', vertex='1', parent='1')
                ET.SubElement(cell, 'mxGeometry', x=str(left), y=str(y-size), width=str(width), height=str(size+9), **{'as':'geometry'})
            else:
                _, pts, color, dashed, both, arrow = item
                cell = ET.SubElement(root, 'mxCell', id=str(i), style=f'edgeStyle=none;rounded=0;html=0;strokeColor={color};strokeWidth=2;dashed={int(dashed)};endArrow={"block" if arrow else "none"};endFill=1;startArrow={"block" if both else "none"};startFill=1;', edge='1', parent='1')
                geom = ET.SubElement(cell, 'mxGeometry', relative='1', **{'as':'geometry'})
                ET.SubElement(geom, 'mxPoint', x=str(pts[0][0]), y=str(pts[0][1]), **{'as':'sourcePoint'})
                ET.SubElement(geom, 'mxPoint', x=str(pts[-1][0]), y=str(pts[-1][1]), **{'as':'targetPoint'})
                if len(pts)>2:
                    arr = ET.SubElement(geom, 'Array', **{'as':'points'})
                    for x, y in pts[1:-1]:
                        ET.SubElement(arr, 'mxPoint', x=str(x), y=str(y))
        ET.indent(doc)
        ET.ElementTree(doc).write(OUT / f'{name}.drawio', encoding='utf-8', xml_declaration=True)


def overview():
    c = Canvas(1800, 1670, 'BCJRFormer microarchitecture', 'Five sequential memory-backed stages, actual core controller links, shared numerical engines, thirteen memory clients, and logical banks. No concurrent inter-stage pipeline is implied.')
    c.header('BCJRFORMER  /  IMPLEMENTED RTL', 'BCJRFormer · ASIC microarchitecture', 'One frame at a time · memory-backed execution · shared numerical engines · provisional fixed-point formats')
    c.box(50, 160, 280, 100, 'Host', ['parameters · features · mask', 'output logits · completion'])
    c.box(430, 160, 1320, 100, 'core_ctrl', ['Load parameters → load frame → dispatch stages → stream outputs → report status'], GREEN)
    c.wire([(330,210),(430,210)], GREEN, both=True)
    c.wire([(1750,210),(1788,210),(1788,1265),(1750,1265)],GOLD,both=True)
    c.text(380,191,'host_if',14,GREEN,anchor='middle')
    c.wire([(1090,260),(1090,294),(200,294)],GREEN,arrow=False)
    c.wire([(1090,294),(1600,294)],GREEN,arrow=False)
    c.text(450,282,'5 independent command/completion channels',16,GREEN)
    stages = [
        ('01  EMBEDDING','embedding_ctrl',['LayerNorm(F) → Linear(F→D)', '→ LayerNorm(D)', 'FEATURE → X']),
        ('02  POSITION','position_ctrl',['Local add / convert', 'X ← X + position + read', 'Parameters: P[N,D], E[M,D]']),
        ('03  ENCODER','encoder_ctrl',['Repeat layer_ctrl × K', 'Attention + residual + FFN', 'X updated in place']),
        ('04  FINAL','final_ctrl',['Linear(D→1), per token', 'Final weight + bias', 'X → LOGIT']),
        ('05  AGGREGATE','aggregation_ctrl',['Mask-aware mean over M', 'N output positions', 'LOGIT → OUTPUT'])]
    for i,(title,module,lines) in enumerate(stages):
        x=50+350*i
        c.wire([(x+150,294),(x+150,330)],GREEN,both=True)
        c.box(x,330,300,190,title,lines)
        c.text(x+20,499,module,16,CYAN)
        if i<4: c.wire([(x+300,427),(x+350,427)],CYAN,dashed=True)
        c.wire([(x+150,520),(x+150,556)],GOLD,both=True)
    c.wire([(200,556),(1775,556),(1775,1246),(1750,1246)],GOLD,arrow=False)
    c.text(50,590,'Dashed cyan arrows show tensor order through memory; they are not direct inter-stage streaming wires.',17,CYAN)
    c.text(50,633,'SHARED PHYSICAL SERVICES',16,MUTED,True)
    c.text(1750,633,'Each engine below exists once in bcjrformer_core',17,MUTED,anchor='end')
    c.rect(50,655,400,485)
    c.text(70,687,'NORMALIZATION',17,CYAN,True)
    c.lines(70,719,['Clients: embedding_ctrl, layer_ctrl'],16)
    c.box(75,746,350,72,'norm_switch',color=GREEN)
    c.wire([(250,818),(250,853)],GREEN,both=True)
    c.box(75,853,350,90,'layernorm_ctrl',['Shared LayerNorm engine'])
    c.wire([(250,943),(250,984)],PURPLE,both=True)
    c.text(269,970,'variance → inverse root',14,PURPLE)
    c.box(75,984,350,76,'rsqrt_unit',color=PURPLE)
    c.lines(75,1090,['Memory: layernorm_ctrl'],16,GOLD)
    c.rect(475,655,650,485)
    c.text(495,687,'LINEAR / DOT / MAC',17,CYAN,True)
    c.lines(495,719,['Linear clients: embedding, QKV, out projection, FFN, final'],16)
    c.box(500,746,270,72,'linear_switch',color=GREEN)
    c.wire([(770,782),(815,782)],GREEN,both=True)
    c.box(815,746,285,72,'linear_ctrl')
    c.wire([(957,818),(957,850),(640,850),(640,880)],GREEN,both=True)
    c.box(500,880,280,72,'dot_switch',color=GREEN)
    c.wire([(780,916),(815,916)],GREEN,both=True)
    c.box(815,880,285,72,'dot_engine')
    c.wire([(957,952),(957,984)],PURPLE,both=True)
    c.box(815,984,285,76,'mac_unit',color=PURPLE)
    c.lines(500,991,['Other dot clients:', 'score_row_ctrl', 'weighted_value_ctrl'],16,GREEN,26)
    c.lines(500,1090,['Memory: linear_ctrl, dot_engine'],16,GOLD)
    c.rect(1150,655,600,485)
    c.text(1170,687,'NONLINEAR / INVERSE',17,CYAN,True)
    c.text(1175,727,'softmax_ctrl',17,GREEN)
    c.text(1475,727,'ffn_ctrl',17,GREEN)
    c.wire([(1300,741),(1300,776)],PURPLE,both=True)
    c.wire([(1600,741),(1600,776)],PURPLE,both=True)
    c.box(1175,776,250,90,'exp_unit',['Taylor · softmax x ≤ 0'],PURPLE)
    c.box(1475,776,250,90,'gelu_unit',['Taylor · exact GELU'],PURPLE)
    c.text(1175,913,'Clients: softmax_ctrl, aggregation_ctrl',16,GREEN)
    c.box(1175,934,550,72,'reciprocal_switch',color=GREEN)
    c.wire([(1450,1006),(1450,1038)],PURPLE,both=True)
    c.box(1175,1038,550,72,'reciprocal_unit',color=PURPLE)
    c.text(50,1178,'MEMORY SYSTEM',16,MUTED,True)
    c.box(50,1200,1700,92,'memory_fabric  ·  13 requesters', ['Core / stage controllers + their numerical services · request / response arbitration · bank / address checks'],GOLD)
    for x in [250,800]:
        c.wire([(x,1140),(x,1200)],GOLD,both=True)
    c.text(275,1169,'Memory client groups (not data streaming)',15,GOLD)
    c.wire([(475,1292),(475,1335)],GOLD,both=True)
    c.wire([(1300,1292),(1300,1335)],GOLD,both=True)
    c.box(50,1335,650,145,'parameter_mem',['PARAM: embedding · position P · read E', 'K encoder layer regions · final weight / bias', 'Canonical packed manifest'],GOLD)
    c.box(740,1335,1010,145,'scratch_mem  ·  17 logical banks', ['FEATURE · MASK · X · U · Q · KEY · VALUE · Z · ATTN_OUT', 'TOKEN · FFN_HIDDEN · VECTOR · SCORE · EXP · PROB · LOGIT · OUTPUT', 'Bank names denote logical storage; physical SRAM mapping remains open'],GOLD)
    c.text(50,1520,'READING THE WIRES',15,MUTED,True)
    legend=[(50,GREEN,False,'command / completion'),(480,PURPLE,False,'arithmetic request / result'),(975,GOLD,False,'memory request / response'),(1450,CYAN,True,'logical tensor order')]
    for x,col,dash,label in legend:
        c.wire([(x,1550),(x+60,1550)],col,dash,both=not dash)
        c.text(x,1581,label,16,col)
    c.text(50,1622,'Clock and reset reach every physical module. Port bundles are SystemVerilog interfaces; arrows summarize ready/valid channels.',16,MUTED)
    c.text(50,1647,'Stage memory trunks include descendant controllers. EXP, GELU, RECIP and RSQRT exchange operands only; they have no memory port.',16,MUTED)
    c.save('bcjrformer-microarchitecture')


def encoder():
    c=Canvas(1800,1420,'BCJRFormer encoder detail','Pre-norm encoder sequencing with two residuals, head and query attention loops, and exact mapping of controller operations to shared engines. Boxes within stage sequences are operations; all named shared engines are instantiated once.')
    c.header('BCJRFORMER  /  STAGE 03', 'Encoder layer · attention and feed-forward', 'Actual controller sequence · K layers · T = M × N tokens · H heads · dₕ = D / H')
    c.box(50,158,1700,85,'encoder_ctrl → layer_ctrl',['Repeat the layer below K times; each phase waits for its child completion and committed writes.'],GREEN)
    # Six phases. Repeated labels are operations on shared services, not duplicate engines.
    phases=[('1  PRE-NORM','LayerNorm₁',['X → U','all T tokens']),('2  ATTENTION','Multi-head attention',['U → ATTN_OUT','all heads / queries']),('3  RESIDUAL','Residual add',['X ← X + ATTN_OUT','all T tokens']),('4  PRE-NORM','LayerNorm₂',['X → U','all T tokens']),('5  FFN','Feed-forward',['U[token] → VECTOR','one token']),('6  RESIDUAL','Residual add',['X[token] += VECTOR','one token'])]
    for i,(label,title,lines) in enumerate(phases):
        x=50+285*i
        c.text(x,286,label,15,GREEN,True)
        c.box(x,306,260,133,title,lines)
        if i<5: c.wire([(x+260,371),(x+285,371)],CYAN,dashed=True)
    c.wire([(1605,439),(1605,475),(1320,475),(1320,439)],GREEN)
    c.text(1460,499,'repeat phases 5–6 for each token',16,GREEN,anchor='middle')
    c.text(50,478,'Two LayerNorm operations call the same norm engine; two residual phases call the same residual_ctrl.',16,MUTED)
    c.rect(50,538,1700,365)
    c.text(75,575,'ATTENTION_CTRL  /  EXPANDED PHASE 2',17,CYAN,True)
    c.text(75,605,'QKV once → for each head h and query q: score row → softmax → weighted values → output projection once',17,MUTED)
    attn=[(75,280,'qkv_ctrl',['Q → KEY → VALUE','all T tokens per projection','Linear(D→D) from U']),(410,280,'score_row_ctrl',['Q[q,h] · KEY[:,h]','scale by 1 / √dₕ','→ SCORE row']),(745,280,'softmax_ctrl',['subtract row maximum','EXP → sum → RECIP','→ PROB row']),(1080,280,'weighted_value_ctrl',['PROB · VALUE[:,h]','→ Z[q,h]']),(1415,310,'output_projection_ctrl',['Z → ATTN_OUT','Linear(D→D)','all T tokens'])]
    for x,w,title,lines in attn:
        c.box(x,645,w,149,title,lines)
    for x,x2 in [(355,410),(690,745),(1025,1080),(1360,1415)]:
        c.wire([(x,718),(x2,718)],CYAN,dashed=True)
    c.wire([(1220,794),(1220,834),(550,834),(550,794)],GREEN)
    c.text(880,863,'H × T row iterations; scratch rows are reused after each weighted-value result',16,GREEN,anchor='middle')
    c.rect(50,930,800,280)
    c.text(75,968,'FFN_CTRL  /  EXPANDED PHASE 5',17,CYAN,True)
    ffn=[(75,225,'Linear D→4D',['U → FFN_HIDDEN']),(340,225,'Taylor GELU',['in-place hidden vector']),(605,220,'Linear 4D→D',['→ VECTOR'])]
    for x,w,title,lines in ffn:
        c.box(x,1008,w,105,title,lines)
    c.wire([(300,1060),(340,1060)],CYAN,dashed=True)
    c.wire([(565,1060),(605,1060)],CYAN,dashed=True)
    c.lines(75,1150,['GELU function returns signed32/F22; hidden storage converts to signed16/F10.'],16,MUTED)
    c.text(75,1178,'The 10⁻⁵ function error bound does not include this later storage conversion.',16,MUTED)
    c.rect(880,930,870,280)
    c.text(905,968,'OPERATIONS → SHARED PHYSICAL ENGINES',17,CYAN,True)
    c.lines(905,1005,[
        'LayerNorm₁,₂ → norm_switch → layernorm_ctrl → rsqrt_unit',
        'QKV / output projection / FFN → linear_switch → linear_ctrl',
        'linear_ctrl / score / weighted → dot_switch → dot_engine → mac_unit',
        'softmax_ctrl → exp_unit + reciprocal_switch → reciprocal_unit',
        'ffn_ctrl → gelu_unit; residual_ctrl performs local add / convert',
        'All tensor reads / writes use the shared memory_fabric'],17,MUTED,31)
    c.wire([(450,1210),(450,1250)],GOLD,both=True)
    c.wire([(1315,1210),(1315,1250)],GOLD,both=True)
    c.box(50,1250,1700,78,'memory_fabric ↔ parameter_mem / scratch_mem',['Tensor arrows above are logical dependencies through banks, rather than direct point-to-point datapaths.'],GOLD)
    c.text(50,1365,'Dashed cyan = tensor dependency     Green = control / loop     Gold = memory     All functional arithmetic is fixed-point.',17,MUTED)
    c.text(50,1393,'Mask handling and empty-row behavior follow controller contracts. STATIC_MASK is unsupported by the current core configuration.',16,MUTED)
    c.save('bcjrformer-encoder-detail')


if __name__ == '__main__':
    overview()
    encoder()
    print('Generated two SVG diagrams and two editable diagrams.net sources.')
