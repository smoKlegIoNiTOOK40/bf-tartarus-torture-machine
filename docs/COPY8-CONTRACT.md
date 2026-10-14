# First joint copy-position QA learning experiment

2026-10-14 before numerical corpus use. All numerical components are frozen
BF: QA codec, eight-word records/shift, native8, copy teacher/resolver and
batched resolver. This is a learning milestone, not completion of the full
conversation/GUI/reproducibility goal.

Data: exact sealed training/wordqa-corpus8-v1/documents.json expanded from
manually authored literal frames. Train96 (key/box/bag/lamp), validation24
(book), test48 (door/bench). Six families each with4 train examples per noun:
item-who, item-what, place-where, place-who, linked-what, linked-where.
Author has seen raw heldout data. Eight-word canonical explicit fact plus
final question tag, not free language. Only answers/EOS are supervised.
Teacher target words -> latest-matching copy actions in BF, EOS priority1,
BOS/absent target refuse. Actual outputs are resolved raw word IDs in BF.

Initial64 embedding digits literally0, frozen260-byte Word80 backbone tail.
E0 stays0; E1 values0..7. Search exactly these25 observed-train axes:
00,29,30,31,06,07,10,11,12,23,24,25,26,13,14,15,16,02,03,04,05,17,19,20,21.
Two sweeps at most, each coordinate eight values from its starting weights;
strict BF improvement only, ties retain old state. Max401 evaluations including
initial. Stop early immediately after a BF comparison proves error0, the
unsigned lower bound. No post-external tuning/replacement or extra sweeps.

Criterion: two-fold whole-noun out-of-fold **resolved word token errors**,
including EOS; not action-ordinal errors when two copies give the same word.
f0 fit key+box/check bag+lamp; f1 reverse. BF fit450 feature and4096 pooled E1
action heads each candidate/fold, raw-last32 and unigram once per fold.
Every count independently verified BF, count ranks and native/reference
action predictions verified BF, resolver words independently selected BF,
word errors checked through safe-label and decimal-ID BF routes and sums.
BF setter, strict comparison and independent full328-byte state selection.
Content hashes reuse repeated byte objects, no candidate source copies.

Before authored numerical use: synthetic two-group four-document toy with
who and what on key/box. Initial zero representation must have6 word errors
across folds; declared who1/what2/carries3 representation must have0. Prove
better/tie/worse whole328-byte selectors and actual generated name/three-word
answer plus EOS. Test actual-history update excludes EOS and appends followup
with BF shift; probe all copied target derivations. Synthetic data are not
the authored corpus and earn no external quality claim.

After search: seal selected weights before full-train refit and before any
heldout encoding/scoring. Export/freeze all model variants before external use.
Main baselines: train unigram action, raw-last action, zero embedding action
heads fitted to train, constant EOS. Required ablation: truncate raw memory
to last four words (older four BOS), for BOTH encoding and copy resolution;
do not leave older raw words accessible to a disabled-history model.
Diagnostic direct-word head: refit actual word labels on selected copy-model
embeddings, decode native labels as words. This is a representation ablation,
not a claim against an independently optimized word-head search.

Generation: at most7 BF model calls per answer. BF resolves predicted action,
compares actual word with00 and01 to issue refusal/EOS decisions; host follows
these control flags and the declared operational call cap. BF decoder emits
actual text, eight-word BF shift feeds back actual non-EOS words, BF sums
the actual call-count flags. Never feed EOS into user-visible conversation
history. Each step/action/word/input/history is preserved and source-bound.

External validation then test once per frozen variant. Encode expected answers
separately only after model seal. Exact document check compares padded14-byte
word-ID traces plus stop reason against target words+EOS and E in BF. Linked
documents require actual first generation+EOS and actual second generation+EOS;
combine both BF errors by BF OR. Gold teacher history may be used for separately
reported token diagnostics/novelty, never as actual linked generation input.
Compare raw16-byte gold contexts to train in BF; require zero overlaps.

Milestone gate, fixed before results: validation<=2 exact document errors,
test<=4; each of six families validation<=1/test<=2; linked combined
validation0/test<=1. Strictly beat all four main baselines on each split's
overall exact errors, and beat truncated history on linked and overall errors.
Train generation and token metrics reported, not used to extend budget.
Keep bad outputs and every failed gate. FullGoalComplete remains false even
on success; GUI related turns and full portable training/eval kit still needed.

Source/data/contract/helper/interpreter archived before first BF. First-use
and final source guards, complete raw journal and artifact proof required.
Exact ready-source assembly only, new complete BF source cap655360.
