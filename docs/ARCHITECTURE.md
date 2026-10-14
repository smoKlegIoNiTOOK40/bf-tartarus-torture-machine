# Copy8 architecture

The current dialogue runtime is an extension of Tartarus's small handwritten
BF Transformer experiment. It is a hybrid feature/copy model, not an ordinary
large autoregressive language model.

## From input to answer

1. A BF word codec maps canonical lowercase words into a 32-slot ABI. The
   dictionary has 30 words; BOS and EOS occupy the other slots. Unknown words
   are rejected by the codec. Host code supplies raw text and record framing.
2. The model retains eight raw word IDs. Its recent four words use the fixed
   width-two quantized backbone. Older/recent four-word embedding contributions
   are pooled modulo eight in BF to form a four-code key.
3. Train-fitted heads select an action: EOS or copying one of the eight raw
   context positions. A 4,096-entry pooled head, 450 feature labels and a
   32-entry last-word fallback form the learned lookup component.
4. A handwritten BF resolver converts the chosen action to the actual current
   context word. A BF decoder emits the word; no host word picker supplies it.
5. BF shifts actual non-EOS output into memory. EOS does not enter conversational
   history. A later user question is appended with the same BF context shift.
   Generation is bounded to seven model calls per answer.

Independent BF reference paths check embeddings, scores/actions, copy
resolution, shifts, stop flags and counts. The host follows those flags and
the declared call cap; it handles process I/O and preservation of byte records.

## What the 4,902 bytes mean

| File | Bytes |
| --- | ---: |
| `model/selected.weights` |324|
| `model/selected.feature.labels` |450|
| `model/selected.fine.labels` |4096|
| `model/selected.bigram.labels` |32|

These sizes describe the model payload, not the interpreter, BF sources,
dictionary or validation machinery. The core 260-byte backbone tail stays
fixed. Training searches 25 declared E1 embedding coordinates; table heads
are fitted in BF on train data. Calling all bytes independently trained
Transformer parameters would misdescribe the implementation.

Copying makes a heldout object word available directly from the input, even
when it did not appear in training answers. This is the intended hypothesis;
heldout objects do not constitute an open-vocabulary language test.

## History and source integrity

Every request keeps its actual BF inputs/outputs and compact raw journal,
then verifies the artifact manifest. The next turn verifies the prior
successful artifact and matching model version before reading its 16-byte
history context. A changed file or different model identity is refused.

The UI commits new memory only after successful generation and checks.
Cancellation and failure retain the last valid memory. New conversation,
model changes and choosing a different fact reset it. Sources are shared
per model version, not copied into each request.

This protects reproducibility and accidental integrity; hash manifests are
not a cryptographic signature or an authentication system.
