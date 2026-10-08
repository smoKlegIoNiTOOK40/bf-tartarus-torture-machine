# Tartarus

**A tiny Transformer in pure Brainfuck — built by a human + Codex duo.**

The question behind Tartarus is simple: how much of a Transformer can we actually make run in Brainfuck, without outsourcing its mathematics to another language?

We are already working on a local prototype. This repository is the public starting point for documenting that work. For now, it contains project information only; the implementation, weights, datasets and test files have not been uploaded.

## Who is building it?

Tartarus is a collaboration between the owner of this repository and **OpenAI Codex**, an AI coding agent.

The human creator initiated the project, sets its constraints and direction, reviews progress and decides what gets published. Codex assists with design, directly authors and edits Brainfuck source and documentation, and runs verification through the available tools.

This is an explicitly AI-assisted project. It is being developed as a duo, and we want that contribution to be visible from the beginning.

## The rules

- Model arithmetic, matrix multiplication, attention, FFN, argmax, autoregressive context updates and output must execute in Brainfuck.
- Brainfuck sources are authored directly. No generator or transpiler produces the BF implementation from another language.
- An ordinary, unmodified Brainfuck interpreter runs the programs.
- No Python, C, Rust, BLAS, NumPy or external numerical runtime performs model computation or training.
- Weights use a fixed format. Synthetic labels, candidate enumeration, error counting, parameter selection, weight export and assertions are also implemented in BF.

Shell tools may edit literal files, route inputs and outputs, and invoke the interpreter. They do not calculate model results. The interpreter itself is the permitted execution mechanism; the restriction concerns the implementation of the model and its computation.

## Current local prototype

Status recorded on **8 October 2026**:

| Component | Implemented locally |
|---|---|
| Architecture | One quantized decoder block, one causal attention head |
| Dimensions | Model width 2, FFN hidden width 2, context 4, vocabulary 4 |
| Forward pass | Embeddings, Q/K/V/O projections, normalized causal attention, residuals, signed ReLU FFN and output head |
| Numbers | Integer arithmetic, signed values, wide accumulators and logits |
| Generation | Up to 99 autoregressive tokens in one interpreter invocation |
| Weights | Fixed 68-field ASCII format, loaded once per invocation |
| Learning | Constrained exhaustive searches over selected head/FFN parameters |
| Latest search | 900 combinations of two FFN biases and two signed diagonal coefficients |
| Verification | BF assertions, modular BF reference passes and complete finite synthetic domains |

The latest experiment learns a synthetic rule over four tokens: answer B when the last token has its low bit set, unless all four tokens have that bit set; otherwise answer A.

Training uses 4 contexts, validation uses 4 different contexts, and testing uses the remaining 248. Errors fell from **14 to 0 on the test partition**, and from **16 to 0 across all 256 contexts**. Candidate error curves were checked against **4,500 complete BF forward passes**.

The local regression currently has **501 positive checks, 68 expected negative controls and 19 passing test suites**.

These are results from our local implementation. They are not yet independently reproducible from this repository because the source and fixtures have not been published.

## What this prototype can do

Tartarus runs a deliberately tiny Transformer and solves versioned synthetic token tasks. Its current learning procedures search a limited set of parameters while the remaining weights are fixed. Different experiments use separate model bundles.

It does not yet implement backpropagation or general training of all Transformer parameters. Natural-language generation remains future work. Layer normalization is not part of the current architecture.

## Next direction

- Give the attention channels independent features.
- Explore joint FFN and output-head learning, including interactions between channels.
- Extend the synthetic curriculum with independently defined teachers and fixed train/validation/test splits.
- Keep explicit integer bounds and compare new arithmetic against BF reference implementations.

## Publication status

The implementation is still being developed locally. Source code, model files, corpora, runnable tests and detailed technical documentation can be published in a later update.

This repository documents the start and progress of **Tartarus**. We are not claiming that it is the first project to attempt a language model or Transformer in Brainfuck.