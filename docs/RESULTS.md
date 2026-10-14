# Copy8 results and their limits

Recorded 14 October 2026. These are results on a tiny synthetic fact language,
not a blind natural-language benchmark. The author saw the raw heldout corpus.
The [pre-training contract](COPY8-CONTRACT.md) fixes the split, budget and gates.

## Dataset

There are 168 authored documents across six families: item-who, item-what,
place-where, place-who, linked-what and linked-where. Linked documents require
both the actual first name answer and a subsequent object/location answer.

- Train:96 documents, nouns key/box/bag/lamp.
- Validation:24 documents, noun book.
- Test:48 documents, nouns door/bench.

Input is an explicit fact with a final question tag. Only answer words and
EOS are supervised. Data and model files are also available under
`evidence/copy8-v1` and `runtime/copy8-v1/model` in this repository.

## Search and external evaluation

The criterion is resolved-word/EOS errors across two whole-noun train folds:
fit key+box/check bag+lamp and the reverse. Search visits the 25 declared
embedding coordinates, eight values each, at most two sweeps. Strict BF
improvement replaces the prior state; ties keep it. A BF-proven zero error
ends search early. The limit was401 evaluations; the selected run used27.

All variants were frozen before external numerical evaluation. No extra
sweeps or post-test replacement were made.

| Variant | Validation exact-document errors /24 | Test errors /48 |
| --- | ---: | ---: |
| Selected Copy8 |0|0|
| Train unigram action |24|48|
| Raw-last-word action |16|32|
| Zero-embedding fitted action heads |24|48|
| Constant EOS |24|48|
| Older four words removed |24|48|
| Direct-word-head diagnostic |22|44|

The direct-word head was refitted on the selected copy embeddings. It is an
ablation, not an independently optimized word-head search. The memory
ablation removes the older words from encoding **and copy resolution**.

Selected generation is exact on96/96 train,24/24 validation and48/48 test.
Both answers and EOS are correct on8/8 linked validation and16/16 linked test
episodes. Actual linked history contains generated answers, not gold names.

BF compared28,224 validation/train and56,448 test/train pairs of raw context
records and found no overlaps. This is a separate gold-context novelty
diagnostic; actual-history generation was checked separately.

## Reproduction and engineering checks

A fresh full source bundle ran3,303 synthetic warmup assertions before authored
training, then137,903 training/evaluation assertions with23,433 physical BF
calls and zero failed BF processes. All source, raw-journal and artifact
checks passed. All four model file hashes matched the original. The repeated
numerical phase took19min47s on the development machine; this is not a promise
for other hardware.

GUI checks passed65 new-dialogue,42 old-Who and27 old-Word80 assertions.
The minimal CLI passed8 portability/negative checks. The complete window
package was moved to a folder containing spaces and passed14 checks across
new dialogue, old Who and old Word80, after each extracted source was verified.
Unknown vocabulary, changed sources/history, mismatched model identity and
cancellation were exercised. These are local checks, not a claim of public CI.

Compact machine-readable results are in `evidence/copy8-v1`. Full replayable
training dependencies are in the reproduction release ZIP. Large historical
logs and preserved failures remain in the development workspace's checked
archive; they are not all included in the public repository.

## What this does not establish

The model has30 words, eight-word memory and a narrowly structured corpus.
The evidence supports these facts and short linked questions, including
heldout object combinations. It does not establish arbitrary English,
long-term memory, contradiction handling, general reasoning, calibrated
uncertainty or learning all Transformer weights. More natural question forms
and three/four-turn retention are future experiments.
