# Reproduce the learned model

Download `tartarus-copy8-reproduce-v0.1.0.zip` from the
[v0.1.0 release](https://github.com/smoKlegIoNiTOOK40/bf-tartarus-torture-machine/releases/tag/v0.1.0).
This is the complete training/evaluation source kit, separate from the small
runtime checked into Git. It needs Windows and PowerShell7; network access,
Python and ML packages are not needed during reproduction.

Extract to a new directory, open PowerShell7 there and run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Reproduce.ps1
```

The entry point:

1. Verifies every frozen source binding.
2. Runs the integrated synthetic warmup before authored-corpus training.
3. Seals the warmup source, then performs the bounded train-only search.
4. Freezes all model variants before validation/test evaluation.
5. Runs required baselines, ablations, linked generation and independent BF checks.
6. Verifies raw records and artifacts, then compares all four selected model
   hashes with the previously published expected files.

Success writes `reproduction-result.json` with `Status: PASS`,
`ModelHashesMatch: true` and `QualityGatesPassed: true`.
Progress logs are `reproduce-warmup.log` and `reproduce-learning.log`.
The local repeats took roughly20–25 minutes for the numerical work.
The source kit expands to roughly538 MB before generated results; its many
handwritten/assembled BF probes compress strongly. Keep sufficient room for
new results and use a fresh extraction for each attempt.

The stable host assembler preserves preexisting `assembly.json` bytes when
the declared plan matches, avoiding process-dependent JSON property order.
Its numerical BF/helper bytes match the original learning experiment. This
host-only assembly change passed its own synthetic warmup in the full repeat;
original source bindings remain in `source-provenance.json`.

Several source seals contain historical `GoalComplete: false` fields. Those
record the state at the time of the numerical experiment, before GUI and
delivery work; they are not rewritten when the later product milestone ends.
The fresh reproduction is judged by its explicit numerical/source/quality
checks and model hashes, not by changing historical status fields.
