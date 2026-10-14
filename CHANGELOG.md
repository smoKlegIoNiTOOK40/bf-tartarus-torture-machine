# Changelog

## v0.1.0 — First runnable BF dialogue — 14 October 2026

The first public runnable release replaces the earlier documentation-only
status. It includes a trained4,902-byte model, standalone offline CLI,
Windows interface and complete source kit for repeating BF learning/evaluation.

- Eight-word actual-output memory and learned who/what/where copy actions.
- Exact24/24 validation and48/48 test; both answers exact in8/8 and16/16
  linked external episodes, within the declared synthetic fact language.
- Independent BF numerical verification; fresh full training reproduced the
  same four model files.
- UI with new-conversation reset, example/followup buttons, cancellation and
  the earlier Who/Word80 modes.
- Shared immutable sources and compact per-request records. Development storage
  fell from50.34GiB to about9.81GiB while preserving failed attempts.
- Public runtime/model source, compact evidence, screenshot, architecture,
  pre-training contract and reproduction instructions.

This is an experimental prerelease. It supports a small fact/query protocol;
it does not claim free conversation or a general-purpose language model.

## Previous public snapshot — stage46 — 10 October 2026

The repository contained the README and calling card only. The local project
had a32-slot character forward engine,324 weight fields, migration from old
bundles and a BF-controlled generation loop. Implementation and reproduction
were not public. That README is preserved in `docs/history/stage46.md`.

Between that snapshot and this release, local work added checked inference
and training objectives, independent numeric paths, word-level generation
and stage80 portability, a first Who question model, eight-word context and
the current trained Copy8 dialogue. Stage numbers track research progress;
release versions track what is actually delivered publicly.
