// Cycle simulator for the Yosys vector netlist. Arithmetic stays in RTL cells;
// this interpreter contains no model-specific controller or inference logic.
const fs=require('fs');
const mask=n=>(1n<<BigInt(n))-1n;
const signed=(x,n)=>n && x>>(BigInt(n)-1n) ? x-(1n<<BigInt(n)):x;
class CycleSimulator {
  constructor(filename,top='core_sim_top') {
    const design=JSON.parse(fs.readFileSync(filename,'utf8')).modules[top];
    this.design=design;this.sources=[];this.drivers=new Map();this.inputs={};this.ports={};
    this.nodes=[];this.registers=[];this.memories=[];
    const source=(bits,owner)=>{
      const s={v:0n,bits,owner,id:this.sources.length};this.sources.push(s);
      bits.forEach((b,i)=>{if(typeof b==='number') {
        if(this.drivers.has(b)) throw Error('Multiple drivers: '+b);
        this.drivers.set(b,{s,bit:i});
      }});return s;
    };
    for(const [name,p] of Object.entries(design.ports)) if(p.direction==='input') this.inputs[name]=source(p.bits,null);
    for(const [name,c] of Object.entries(design.cells)) {
      const node={name,type:c.type,parameters:c.parameters,connections:c.connections,outputs:{},reads:{},last:null};
      for(const [port,direction] of Object.entries(c.port_directions)) if(direction==='output') node.outputs[port]=source(c.connections[port],node);
      if(c.type==='$dff') {
        if(parseInt(c.parameters.CLK_POLARITY,2)!==1 || c.connections.CLK[0]!==design.ports.clk.bits[0])
          throw Error('Only the common positive clock is supported');
        this.registers.push(node);
      }
      else if(c.type==='$mem_v2') {
        const number=k=>parseInt(c.parameters[k],2);
        node.width=number('WIDTH');node.size=number('SIZE');node.offset=number('OFFSET');
        node.readPorts=number('RD_PORTS');node.writePorts=number('WR_PORTS');node.abits=number('ABITS');
        if(parseInt(c.parameters.RD_CLK_ENABLE,2)!==0) throw Error('Clocked memory reads unsupported');
        if(node.writePorts && (BigInt('0b'+c.parameters.WR_CLK_ENABLE)!==mask(node.writePorts) ||
           BigInt('0b'+c.parameters.WR_CLK_POLARITY)!==mask(node.writePorts) ||
           c.connections.WR_CLK.some(b=>b!==design.ports.clk.bits[0])))throw Error('Unsupported memory write clock');
        node.memory=Array.from({length:node.size},(_,i)=>{
          const end=c.parameters.INIT.length-i*node.width;
          const raw=c.parameters.INIT.slice(end-node.width,end);
          return BigInt('0b'+raw.replace(/[xz]/g,'0'));
        });node.revision=0;this.memories.push(node);this.nodes.push(node);
      } else {if(!c.type.startsWith('$')) throw Error('Unlowered module '+c.type);this.nodes.push(node);}
    }
    const read=bits=>{
      let groups=[],constant=0n;
      bits.forEach((bit,position)=>{
        if(typeof bit==='string') {if(bit==='1')constant|=1n<<BigInt(position);return;}
        const d=this.drivers.get(bit);if(!d)throw Error('Undriven bit '+bit);
        const previous=groups.at(-1);
        if(previous && previous.s===d.s && previous.from+previous.width===d.bit && previous.to+previous.width===position) previous.width++;
        else groups.push({s:d.s,from:d.bit,to:position,width:1});
      });
      groups=groups.map(g=>({...g,from:BigInt(g.from),to:BigInt(g.to),mask:mask(g.width)}));
      let previous=null,cached=constant;
      const get=()=>{
        if(previous && groups.every((g,i)=>g.s.v===previous[i]))return cached;
        previous=groups.map(g=>g.s.v);
        cached=groups.reduce((v,g)=>v|(((g.s.v>>g.from)&g.mask)<<g.to),constant);
        return cached;
      };
      get.dependencies=[...new Set(groups.map(g=>g.s.owner).filter(Boolean))];return get;
    };
    for(const node of [...this.nodes,...this.registers]) for(const [port,bits] of Object.entries(node.connections))
      if(!(port in node.outputs))node.reads[port]=read(bits);
    for(const [name,p] of Object.entries(design.ports))this.ports[name]=read(p.bits);
    // Slang retains some optimized-away automatic-function locals as debug
    // netnames. They have no drivers and no consumers; do not expose those as
    // observable signals. Functional ports/cell inputs still reject undriven bits.
    this.wires={};for(const [name,p] of Object.entries(design.netnames))
      if(p.bits.every(b=>typeof b==='string' || this.drivers.has(b)))this.wires[name]=read(p.bits);
    const visited=new Set(),active=new Set(),order=[];
    const visit=node=>{
      if(node.type==='$dff' || visited.has(node))return;
      if(active.has(node))throw Error('Combinational cycle: '+node.name);
      active.add(node);for(const r of Object.values(node.reads))for(const dep of r.dependencies)visit(dep);
      active.delete(node);visited.add(node);order.push(node);
    };
    this.nodes.forEach(visit);this.nodes=order;this.cycles=0;
  }
  set(values){for(const [name,v] of Object.entries(values)){
    if(!this.inputs[name])throw Error('Unknown input '+name);
    this.inputs[name].v=BigInt(v)&mask(this.inputs[name].bits.length);
  }}
  get(name){return this.ports[name]();}
  evaluate(){
    for(const n of this.nodes){
      const ports=Object.keys(n.reads),v=ports.map(p=>n.reads[p]());
      if(n.type==='$mem_v2')v.push(BigInt(n.revision));
      if(n.last && n.last.length===v.length && v.every((x,i)=>x===n.last[i]))continue;
      n.last=v;const a=Object.fromEntries(ports.map((p,i)=>[p,v[i]]));
      const num=k=>parseInt(n.parameters[k]||'0',2);
      const aw=num('A_WIDTH'),bw=num('B_WIDTH');
      const bothSigned=num('A_SIGNED') && num('B_SIGNED');
      const A=bothSigned ? signed(a.A,aw):a.A,B=bothSigned ? signed(a.B,bw):a.B;
      const unary=num('A_SIGNED') ? signed(a.A,aw):a.A;
      let y=0n;
      switch(n.type){
        case '$mux':y=a.S ? a.B:a.A;break;
        case '$pmux':{
          y=a.A;let found=false;const width=num('WIDTH');
          for(let i=0;i<num('S_WIDTH');i++)if((a.S>>BigInt(i))&1n){
            if(found)throw Error('Conflicting parallel mux '+n.name);found=true;y=(a.B>>BigInt(i*width))&mask(width);
          }break;
        }
        case '$bmux':y=(a.A>>(a.S*BigInt(num('WIDTH'))))&mask(num('WIDTH'));break;
        case '$demux':y=a.A<<(a.S*BigInt(num('WIDTH')));break;
        case '$add':y=A+B;break;case '$sub':y=A-B;break;case '$mul':y=A*B;break;
        case '$div':y=B===0n ? mask(num('Y_WIDTH')):A/B;break;
        case '$mod':y=B===0n ? mask(num('Y_WIDTH')):A%B;break;
        case '$eq':y=BigInt(A===B);break;case '$ne':y=BigInt(A!==B);break;
        case '$lt':y=BigInt(A<B);break;case '$le':y=BigInt(A<=B);break;
        case '$gt':y=BigInt(A>B);break;case '$ge':y=BigInt(A>=B);break;
        case '$logic_and':y=BigInt(a.A!==0n && a.B!==0n);break;
        case '$logic_or':y=BigInt(a.A!==0n || a.B!==0n);break;
        case '$logic_not':y=BigInt(a.A===0n);break;
        case '$reduce_or':case '$reduce_bool':y=BigInt(a.A!==0n);break;
        case '$reduce_and':y=BigInt(a.A===mask(aw));break;
        case '$or':y=A|B;break;case '$and':y=A&B;break;case '$xor':y=A^B;break;
        case '$not':y=~unary;break;case '$neg':y=-unary;break;
        case '$shl':case '$sshl':y=unary<<a.B;break;
        case '$shr':y=a.A>>a.B;break;case '$sshr':y=unary>>a.B;break;
        case '$mem_v2':{
          for(let i=0;i<n.readPorts;i++){
            const address=Number((a.RD_ADDR>>BigInt(i*n.abits))&mask(n.abits))-n.offset;
            const word=n.memory[address]??0n;y|=word<<BigInt(i*n.width);
          }
          n.outputs.RD_DATA.v=y;continue;
        }
        default:throw Error('Unsupported netlist cell '+n.type+' '+n.name);
      }
      n.outputs.Y.v=y&mask(n.outputs.Y.bits.length);
    }
  }
  tick(){
    this.set({clk:0});this.evaluate();
    const next=this.registers.map(n=>n.reads.D());
    for(const n of this.memories)for(let i=0;i<n.writePorts;i++){
      const enables=(n.reads.WR_EN()>>BigInt(i*n.width))&mask(n.width);
      if(!enables)continue;
      const addr=Number((n.reads.WR_ADDR()>>BigInt(i*n.abits))&mask(n.abits))-n.offset;
      if(addr<0 || addr>=n.size)throw Error('Out-of-range write '+n.name);
      const data=(n.reads.WR_DATA()>>BigInt(i*n.width))&mask(n.width);
      n.memory[addr]=(n.memory[addr]&~enables)|(data&enables);n.revision++;
    }
    this.registers.forEach((n,i)=>n.outputs.Q.v=next[i]);
    this.set({clk:1});this.evaluate();this.cycles++;
  }
}
module.exports={CycleSimulator,signed};
