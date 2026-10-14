# Tartarus

**A tiny Brainfuck model that answers questions and remembers the previous turn.**

Tartarus is a human + Codex experiment in handwritten Brainfuck. It has grown
from a small Transformer forward pass into a learned, restricted dialogue model
with a Windows interface, an offline CLI and reproducible BF training.

**14 October 2026 · Copy8 milestone · first runnable release: v0.1.0.**

[Download the release](https://github.com/smoKlegIoNiTOOK40/bf-tartarus-torture-machine/releases/tag/v0.1.0)
· [Русское описание](README.ru.md) · [Results](docs/RESULTS.md)
· [Architecture](docs/ARCHITECTURE.md) · [Reproduce training](docs/REPRODUCE.md)

![Tartarus answering a linked who/what question in its Windows interface](assets/dialogue-copy8.png)

## Try it

Download **tartarus-copy8-windows-v0.1.0.zip** from the release, extract the
whole folder and open **Tartarus.exe**. Windows PowerShell 5.1 and WPF are
already part of the supported Windows setup. No network, Python, ML library
or model server is needed. The interface is currently Russian; model input
is lowercase English.

The default mode is **Диалог · 8 слов**. Select an example and press **Спросить**:

```text
mira carries a red key who
→ mira

what
→ a red key
```

For a location:

```text
oren rests near the bench who
→ oren

where
→ near the bench
```

The followup receives the model's actual previous answer. **Новая беседа**
starts with empty memory. Selecting a different example also starts fresh.
The older Who v1 and Word 80 continuation modes remain in the model picker.

This is a deliberately small language of explicit facts followed by
`who`, `what` or `where`, plus short linked questions. Arbitrary English,
open-ended chat, long conversations and unseen vocabulary are outside the
verified scope. These examples show the supported format, not general fluency.

### Command line

Clone this repository, then use the included, already trained runtime:

```powershell
Set-Location .\runtime\copy8-v1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\demo.ps1 -Prompt 'mira carries a red key who' -OutputDirectory .\runs\first
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\demo.ps1 -Prompt 'what' -HistoryContextPath .\runs\first\final-history.context
```

Use a fresh output directory for another run. Omit `HistoryContextPath` to
start without previous memory. The standalone CLI ZIP has the same runtime.
From the repository root, `powershell.exe -NoProfile -ExecutionPolicy Bypass
-File .\Check.ps1` verifies its sealed sources and model without inference.

## What is inside?

| Component | Current dialogue model |
| --- | --- |
| Learned model payload | **4,902 bytes**, four files |
| Vocabulary | **30 words**, plus BOS/EOS |
| Available context | **8 words**, including actual previous output |
| Questions | Person, object and place: `who`, `what`, `where` |
| Generation | Learned copy-position actions resolved to current context words by BF |
| Training | Bounded discrete embedding search and BF-fitted action heads |
| Backbone | Width-two quantized Transformer-derived features; fixed core |
| Host | PowerShell/WPF for UI, process transport, byte framing and archives |
| Numerical execution | Ordinary, unmodified qdb interpreting handwritten BF |

The 4,902 bytes include **324 weight bytes and 4,578 table-label bytes**.
They are not 4,902 independently trained Transformer weights. Most of the
backbone is fixed. Eight-word pooling and learned copy heads extend the
original four-word backbone; [architecture details](docs/ARCHITECTURE.md)
explain the difference from a conventional language model.

## Measured results

The synthetic corpus, split, search budget, comparisons and success gates
were fixed before numerical training. The author had seen the raw heldout
examples; this is not a blind benchmark.

| Partition | Exact answer and EOS |
| --- | ---: |
| Train | **96/96** |
| Validation, heldout `book` | **24/24** |
| Test, heldout `door` / `bench` | **48/48** |
| Linked validation episodes, both answers | **8/8** |
| Linked test episodes, both answers | **16/16** |

Train-only search reached its BF-verified zero-error lower bound after
**27 of at most 401 evaluations**. All four predeclared baselines were worse
on both external splits; removing the older half of memory also made results
worse. Linked generation used actual first answers, never gold-name substitution.

A fresh full reproduction passed **3,303 synthetic warmup assertions**, then
**137,903 learning/evaluation assertions with 23,433 physical BF invocations**.
All four exported model files matched the original hashes exactly. Numerical
source, raw-I/O and artifact checks passed. [Results and limitations](docs/RESULTS.md)
include baseline errors and the verification scope; [the contract](docs/COPY8-CONTRACT.md)
is preserved as written before training.

## Downloadable packages

| Asset | Use |
| --- | --- |
| `tartarus-copy8-windows-v0.1.0.zip` | Windows UI, trained dialogue and older model modes |
| `tartarus-copy8-cli-v0.1.0.zip` | Minimal standalone CLI, trained model and numerical checks |
| `tartarus-copy8-reproduce-v0.1.0.zip` | Complete frozen source, corpus, training and evaluation; PowerShell 7 |
| `SHA256SUMS.txt` | Checksums of the three ZIP files |

The source checkout includes the minimal runtime, model, GUI sources and
compact evidence. Use the GUI ZIP to run the window with all three model
packages. Full research dependencies are distributed in the reproduction
ZIP rather than adding hundreds of megabytes of assembled probes to Git.
Large historical local logs remain archived locally; they are not claimed
as downloadable artifacts. Release packages preserve the verified numerical
bytes and add English startup instructions and interpreter attribution.

## The rules

- BF source is handwritten. Automated assembly only copies and concatenates
  ready fragments byte for byte; no transpiler, macro or template generates BF.
- Model arithmetic, teacher targets, training counts, selection, inference,
  word copying, decoding and independent numerical verification execute in BF.
- Host tools handle literal input, files, byte framing, hashes, processes and UI.
  They do not predict an answer or calculate the model's loss.
- Executed boundary checks include deliberate bad joins. Source hashes and
  raw input/output records bind the numerical results to their actual sources.

See [SOURCE-RULES.md](SOURCE-RULES.md). The unmodified interpreter is by
[Daniel B. Cristofani](https://www.brainfuck.org/); its original readme and
[attribution](THIRD-PARTY-NOTICES.md) are included.

## Progress

The previous public update stopped at **stage 46**, with documentation and a
32-slot character engine. Since then, the project gained checked objectives
and training, word-level generation, the stage-80 portable model, a first
Who question model, and this eight-word copy-based dialogue milestone.

The local workspace was reduced from **50.34 GiB to about 9.81 GiB**, including
new research and preserved failures. A checked GUI query now retains roughly
**175–330 KB** instead of copying a roughly 300 MB research bundle. That is
storage overhead, separate from the 4,902-byte model.

[Changelog](CHANGELOG.md) · [Archived stage-46 README](docs/history/stage46.md)

Next research directions are more natural question forms and measured memory
across three or four turns. They are recommendations, not promises of general
language ability or a schedule tied to stage numbers.

## Who is building it?

Tartarus is built by [smoKlegIoNiTOOK40](https://github.com/smoKlegIoNiTOOK40)
and **OpenAI Codex**. The human creator sets the constraints and direction,
reviews progress and decides what to publish. Codex assists with design,
directly authors and edits BF source and host tools, writes documentation
and runs checks. AI involvement is disclosed explicitly.

This is an experimental release, not a production chatbot. No claim of being
the first Brainfuck Transformer or language-model project is made.