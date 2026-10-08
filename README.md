# Tartarus

![Tartarus project calling card: Pure Brainfuck Transformer, 8 tokens, 108 weight fields](assets/tartarus-card.png)

**A tiny Transformer in handwritten Brainfuck, built by a human + Codex duo.**

Tartarus asks how much of a Transformer can run in Brainfuck when its mathematics stays in Brainfuck. The local prototype now generates two short sequences: **hello hi** and **hi hi**, then stops at EOS.

This repository currently publishes project information and the creator's calling card. The implementation, weights, corpora and runnable tests remain local.

## Who is building it?

Tartarus is a collaboration between [smoKlegIoNiTOOK40](https://github.com/smoKlegIoNiTOOK40), the human creator, and **OpenAI Codex**, an AI coding agent.

The human creator started the project, sets its constraints and direction, reviews progress and decides what gets published. Codex assists with design, directly authors and edits BF source and documentation, and runs verification through the available tools. AI involvement is disclosed explicitly.

## Current local prototype

Status recorded on **9 October 2026 — stage 25, V9**.

| Component | Current implementation |
| --- | --- |
| Architecture | One quantized decoder block, one causal attention head |
| Dimensions | Model width 2, FFN hidden width 2, context 4 |
| Vocabulary | 8 IDs: BOS, EOS, h, i, e, l, o, space |
| Forward pass | Embeddings, Q/K/V/O projections, normalized causal attention, residuals, signed ReLU FFN and output head |
| Arithmetic | Integers, signed values, wide accumulators and logits |
| Weights | Fixed 108-field ASCII format |
| Latest learning | 1,600 candidates over four parameters; 5 mutable fields, 103 manually fixed fields |
| Generation | EOS stops normal output; diagnostic mode supports up to 99 autoregressive steps |

Earlier versions progressed from four-token synthetic rules through learned positional copy tasks and single-word generation. Separate bundles preserve those experiments.

## Latest result: two short phrases

From two different starting contexts, the learned bundle produces:

```text
hello hi
```

```text
hi hi
```

Both sequences also work from held-out prefixes. Each next ID is computed by the BF Transformer. The BF decoder maps IDs to characters; it contains no completed phrases.

The previous combination experiment exposed a feature collision: different contexts needed either a space or EOS but reached the same representation. The new bounded family separates those features and makes space available as an output.

A BF search learns a tied BOS/EOS embedding marker and three output biases. That is four degrees of freedom across five weight fields; the other 103 fields, including the form of the embedding, attention and FFN, are chosen manually. Selection uses only the nine training examples and retains the earliest minimum.

| Partition | Examples | Initial errors | Learned errors |
| --- | ---: | ---: | ---: |
| Training | 9 | 4 | 0 |
| Validation | 6 | 1 | 0 |
| Test | 6 | 3 | 0 |
| Total | 21 | 8 | 0 |

The split and numerical family were fixed before the search. The same 21 contexts were retained from the preceding experiment, with two examples exchanging training/validation membership before this stage.

## Verification

All numerical references, error counting, candidate selection, exports and assertions execute in BF.

- All 1,600 candidate losses were checked against **14,400 complete Transformer forward passes**.
- All **4,096 four-token contexts** were checked for features, all eight complete wide output scores, the winning score and token.
- A separate BF context update/reference path matched **99 diagnostic generation steps**, including EOS feedback.
- Tests cover EOS stopping, held-out prefixes, tied fields, exact exports, earliest ties, reordered training data and malformed inputs, including corruption of only a score's high byte.

The latest stage adds **6,303 positive component checks and 28 expected negative controls across six suites**.

The cumulative local ledger is **28,054 positive checks, 837 expected negative controls and 68 passing suite verdicts**. All six new suites and earlier word/combination static tests were run freshly. The remaining expensive older suites were included through saved verdicts; the aggregate is not a fresh rerun of every historical test.

These are locally recorded results. They cannot yet be independently reproduced from this public repository because the implementation and fixtures have not been published.

## The rules

- Model arithmetic, matrix multiplication, attention, FFN, argmax, autoregressive context updates and output execute in Brainfuck.
- BF source is authored directly. No generator or transpiler produces it from another language.
- An ordinary, unmodified BF interpreter runs the programs.
- No Python, C, Rust, BLAS, NumPy or external numerical runtime performs model computation or training.
- Weights use fixed formats. Synthetic labels, enumeration, error counting, selection, weight export and assertions are also implemented in BF.

Shell tools edit literal files, route inputs and outputs, and invoke the interpreter. They do not calculate model results. The interpreter is the permitted execution mechanism.

## Limits and next steps

Tartarus currently solves a deliberately tiny synthetic task. It does not implement backpropagation, general training of all weights, layer normalization or open-ended language generation. The teacher defines targets for 21 contexts; the exhaustive numerical check does not give the other contexts meaningful language labels.

A four-token context still cannot distinguish every phrase ending. Supporting both hello hi and the opposite ordering hi hello requires a separate memory/context change.

Next comes the format, transport and numerical bounds for **16 IDs**, while preserving the 8-ID bundles as regressions. A full lowercase alphabet would need **29 active IDs**: 26 letters, space, BOS and EOS. Synthetic datasets will stay small, versioned and explicit about their partitions.

## Publication status

Source code, model bundles, datasets, runnable tests and detailed technical reports can be published in a later update. For now, this repository documents the progress of Tartarus.

We are not claiming to be the first project to attempt a language model or Transformer in Brainfuck.
