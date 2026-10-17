// Review scope: keep the encoder opaque and use brief interface descriptions.
const shortDescriptions = {
 system: 'Prepared window features and a padding mask enter the core. Raw prediction scores leave it.',
 core: 'Five processing stages convert window features into one binary logit per encoded position.',
 embed: 'Normalizes each window, projects F features to D, then normalizes again.',
 reshape: 'Reindexes each window as one feature vector without changing its values.',
 lnf: 'Normalizes the F features of each input window.',
 inproj: 'Uses learned weights and a bias to map F input features to D features.',
 lnd: 'Normalizes the D features of each projected token.',
 position: 'Adds P[n] and E[m]. Both are trained parameters loaded from the checkpoint and read from memory during inference.',
 posadd: 'Reads the trained vector P[n] and adds it to the token at encoded position n.',
 seqadd: 'Reads the trained vector E[m] and adds it to tokens from read slot m.',
 encoder: 'Processes the Stage 2 tokens using the padding mask. Internal architecture and FSM are not defined in this review.',
 final: 'Maps each D-component token to one binary prediction score using learned weights and a bias.',
 aggregate: 'Zeros padded scores, sums across reads, and divides by the valid-read count. With one read slot, this stage is bypassed.',
 zero: 'Replaces padded logits with zero before summation.',
 sum: 'Adds logits from different reads at the same encoded position.',
 count: 'Counts read slots with no padded positions.',
 divide: 'Divides the summed logits by the valid-read count.'
};
for (const id of Object.keys(pages)) {
 if (!(id in shortDescriptions)) { delete pages[id]; continue; }
 pages[id].why = shortDescriptions[id];
 pages[id].intro = id === 'encoder' ? 'Black box · inputs and outputs only' : 'Select a block for a brief description and its connections.';
 delete pages[id].note;
}
pages.encoder.title = '3 · Transformer encoder (black box)';
pages.encoder.input = 'Stage 2 tokens [B,L,D] and padding mask';
pages.encoder.output = 'Tokens [B,L,D] → final projection';
pages.encoder.source = 'bcjrformer.py';
pages.aggregate.note = 'The count uses fully unpadded read slots and must be greater than zero.';
pages.divide.note = 'Requires at least one valid read (C > 0).';
const encoderNode = pages.core.nodes.find(node => node.id === 'enc');
encoderNode.sub = 'Black box · internals pending';
graph('encoder',[
 n('input',null,2,1,'Stage 2 tokens','[B,L,D]','port'),
 n('mask',null,1,2,'Padding mask','[B,M,N] before reshape','mask'),
 n('box',null,2,2,'Transformer encoder','Black box · internals pending','current'),
 n('output',null,2,3,'Tokens → final projection','[B,L,D]','port')
],[e('input','box'),e('mask','box','mask'),e('box','output')]);
