# BCJRFormer architecture with code

Speaker notes for all 19 slides. Use the diagrams for the main explanation and point out selected lines on the code slides.

## Slide 1: BCJRFormer ASIC architecture

Today we want to present the hardware architecture we have developed so far for BCJRFormer. I will first show what enters and leaves the core, then walk through its five main blocks. After that, I will explain the two initial controller sketches and show which FSMs still need design work. The purpose of this meeting is to agree on the next hardware steps. We are presenting an architecture proposal, not a completed or validated chip.

## Slide 2: The neural-network core

This is the boundary we are using for the first architecture. The inputs are prepared features extracted from the noisy reads and a padding mask. The mask identifies missing or padded read slots. The output is a score for each encoded position, called a logit. It is not yet the final decoded message. Window preparation and hard decisions sit outside this neural-network core. A complete storage decoder may also need a separate outer error-correction stage.

## Slide 3: Five main blocks

The model has five main stages. Input embedding prepares the received information for the network. Position and sequence embedding add information about where a token belongs. The transformer stack combines information across the sequence and across reads. The final projection turns each token into a prediction score. Sequence aggregation combines those scores across received copies. These are logical blocks. The number of physical arithmetic units and controllers still depends on how we share hardware.

## Slide 4: Block 1: Input embedding

This block prepares each token for the transformer. First it measures the input vector and normalizes it. Then a learned linear calculation maps it to the model width, followed by another normalization. Our saved diagram contains eight state labels, including idle, loading, and writing. This is only the first controller sketch. A calculation state can take many cycles. We still need to define the handshake, token loop, memory timing, and arithmetic precision before turning it into RTL.

## Slide 5: Block 1: Python implementation

The highlighted block is input embedding. These lines show the exact sequence: normalization, a linear projection, and a second normalization. The view operation prepares each token’s input shape. The final line runs the embedding on the input. Our eight-state sketch controls how hardware would perform these operations over time. The Python itself does not define eight states.

## Slide 6: Block 2: Position and sequence embedding

This block tells the network where each token belongs. It adds one learned vector for the encoded position and another for the received-sequence slot. The initial controller sketch also has eight states. It loads the token, reads and adds the two vectors, writes the result, and updates the indices. If more tokens remain, it returns to loading. Otherwise it returns to idle. Some operations could overlap later, so the final state count is still open.

## Slide 7: Block 2: Python implementation

We are now in position and sequence embedding. The first two lines define the learned embedding tables. In the forward pass, the model changes its view of the tokens, adds the position vector, and adds the sequence vector. The plus-equals lines are the two additions shown in our diagram. The sequence_to_embed index setup is elsewhere in the constructor. We do not need to read every line aloud.

## Slide 8: Block 3: Transformer stack

The transformer is the main computation block. Each layer has attention, a feed-forward calculation, normalization, and additions that preserve the earlier representation. Attention shares information between tokens. The feed-forward part improves each token individually. The same layer structure repeats, but each layer has its own learned parameters. The paper calls BCJRFormer decoder-only, while the code calls this class TransformerEncoder. There is no missing second transformer stack. We have defined the structure, but have not finalized its controller or hardware sharing. The bypass operands are the original layer input for the first addition and the first residual result for the second.

## Slide 9: Block 3: Repeated transformer layers

This is the outer transformer stack. The first excerpt creates the stack using the configured number of layers. The second excerpt runs the layers one after another. The object is named decoder, while the class is called TransformerEncoder. Both refer to the same computation stack. We still need to decide whether one hardware engine runs all layers or whether we build several engines.

## Slide 10: Block 3: One layer in Python

These few lines describe one complete layer. First the input is normalized. Self-attention then produces an update, which is added to the original input. Next the feed-forward block processes another normalized version, and its result is added back. These are exactly the two computation branches and residual additions in the architecture.

## Slide 11: Block 3: Feed-forward code

This is the feed-forward part inside the transformer. It uses a linear calculation, GELU activation, and another linear calculation. The activation allows a nonlinear transformation of the token features. The software also includes dropout, which is inactive during evaluation. The constructor supplies a hidden width of four times the model width. We have not yet selected the hardware schedule or FSM for this part.

## Slide 12: Inside the attention block

This slide opens the attention block one level. Queries and keys let the network compare tokens and calculate relevance scores. Those scores become weights, and the weights determine how to combine the value vectors. An output projection prepares the result for the residual addition. We do not need the detailed equations for this discussion. The key hardware question is whether these calculations share an arithmetic engine. That choice, together with memory access, determines the controller states. We have not fixed an attention FSM count yet. Masking and head splitting are omitted from this simplified diagram. The attention-mask behavior remains a code-review item.

## Slide 13: Attention: Queries, keys and values

We remain inside block three, now inside attention. These lines create separate learned projections for queries, keys, and values. Each projection uses the same normalized input but different learned parameters. The rearrange lines split the features into attention heads. The constructor also defines the final output projection. The architecture can implement the three projections with separate units or a shared engine.

## Slide 14: Attention: Scores and weighted values

This excerpt follows the attention data path. The model compares queries and keys, applies masks, converts the scores into weights with softmax, and uses those weights to combine values. It then joins the heads and applies the output projection. The optional cache only records attention for inspection. We are showing the current source as written, including the mask behavior that still needs review before hardware is frozen.

## Slide 15: Blocks 4 and 5: Output prediction

The final projection converts the transformer features into a score for each token. Sequence aggregation then combines scores belonging to the same encoded position across the received reads. In the multi-read path, the code zeros padded entries and divides the sum by the valid-read count. With one read, the model bypasses this aggregation. These operations are simpler than attention, but they still need memory control and a schedule. Neither block has a completed FSM sketch in our saved artifacts.

## Slide 16: Block 4: Final projection code

The location strip now highlights only block four. The final linear layer changes the model-width feature vector into the required number of output channels. For our binary target, that is one score per token. The squeeze removes the size-one output dimension. This is different from the attention output projection, which keeps the model width.

## Slide 17: Block 5: Sequence aggregation code

The final block combines scores from multiple read slots. It counts the completely valid sequence slots, zeros padded scores, sums across reads, and divides by the valid count. If there is only one read slot, the model skips this branch and returns the score directly. Our hardware controller for this block is still undefined. These lines provide the required computation, but not the timing or state count.

## Slide 18: Current FSM status

This table is the most important status summary. We currently have two initial FSM sketches, and each has eight named states. The transformer, final projection, and aggregation controllers are not yet defined. We should not describe the whole chip as having sixteen states, because these are separate draft controllers, and more control logic will be needed. A top-level controller may coordinate the blocks. Attention and other sub-blocks may have local controllers, but their number depends on the hardware partition. Even after we choose the states, one state may take several cycles.

## Slide 19: Next decisions with Amit

The next step is to agree on the architecture assumptions that control the FSM design. First, should our first chip stop at the BCJRFormer output scores, with preprocessing and outer decoding outside? Second, how much hardware should we reuse, especially inside attention and across transformer layers? Third, once we choose that schedule, we can finish the FSMs and estimate memory and cycle counts. In parallel, we still need to confirm a useful software checkpoint and evaluation baseline. Today I would like Amit’s feedback on whether this scope and order of work are appropriate.
