# Tartarus v0.1.0 — First runnable BF dialogue

The first release you can actually run. Since the previous public stage-46
README, Tartarus has gained a trained word model, eight-word dialogue memory,
a Windows interface and complete reproducible BF learning/evaluation.

## Download

- **[Windows window](https://github.com/smoKlegIoNiTOOK40/bf-tartarus-torture-machine/releases/download/v0.1.0/tartarus-copy8-windows-v0.1.0.zip)** — extract everything and open `Tartarus.exe`. Includes the new dialogue and earlier Who/Word80 modes.
- **[Minimal CLI + trained model](https://github.com/smoKlegIoNiTOOK40/bf-tartarus-torture-machine/releases/download/v0.1.0/tartarus-copy8-cli-v0.1.0.zip)** — about128KB compressed, offline inference with independent BF checks.
- **[Full training/evaluation source kit](https://github.com/smoKlegIoNiTOOK40/bf-tartarus-torture-machine/releases/download/v0.1.0/tartarus-copy8-reproduce-v0.1.0.zip)** — about9.1MB compressed; requires Windows and PowerShell7. See `START-HERE.md`.
- **[SHA256SUMS.txt](https://github.com/smoKlegIoNiTOOK40/bf-tartarus-torture-machine/releases/download/v0.1.0/SHA256SUMS.txt)** — checksums for all three ZIPs.

The Windows UI is Russian; input is lowercase English. Runtime use needs
Windows PowerShell5.1/WPF and no network, Python, ML package or model server.
The EXE opens the bundled scripts; extract the complete package.

## A tiny actual conversation

```text
mira carries a red key who
→ mira

what
→ a red key
```

The second question receives the model's actual previous output. A location
example is `oren rests near the bench who`, then `where` → `near the bench`.

## What changed

- 4,902-byte learned payload,30 words and eight-word context.
- BF executes model arithmetic, training, copy-position selection, decoding
  and independent numerical verification; host code handles files, I/O and UI.
- Exact24/24 validation and48/48 test; both answers and EOS correct in8/8
  and16/16 linked external episodes. All four predeclared baselines were worse.
- Fresh full BF training/evaluation reproduced all four model files exactly.
- New-conversation reset, saved actual history, friendly unknown-word handling
  and cancellation that also stops the BF child.
- Shared source snapshots and compact query archives replace repeated full
  package copies. Failed historical attempts remain preserved locally.
- The repository now contains the current inference source/model, GUI source,
  compact evidence, pre-training contract and reproduction instructions.

## Experimental scope

This prerelease supports a small explicit-fact language with a final
who/what/where tag and short linked questions. It does not establish arbitrary
English or long conversations. The author saw raw heldout data; these results
are not a blind benchmark. The payload includes trained table labels and a
mostly fixed Transformer-derived core, not4,902 freely trained Transformer
weights. Full details are in the repository's `docs/RESULTS.md`.

Built by smoKlegIoNiTOOK40 + OpenAI Codex. The ordinary unmodified qdb
interpreter is by Daniel B. Cristofani; its original readme is preserved.
