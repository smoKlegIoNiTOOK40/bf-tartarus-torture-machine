# Host IO audit v2

This layer handles files, SHA256, exact byte copying, paths and routing counters.
It never launches BF, calculates a model/teacher value, selects a candidate,
checks numerical correctness, or generates BF commands. SOURCE-RULES.md applies.
This is infrastructure for NEW runners. Frozen stage71 and earlier sources and
archives remain immutable. Include this layer and its tests in the next source
freeze before using it in a credited numerical run.

## Files and operations

- MetadataJson.cs: streaming UTF-8 metadata JSON reader/writer; rejects malformed
  syntax, duplicate properties, invalid surrogates and invalid integer counts.
- FileAudit.cs: shared bounded parallel SHA engine, manifest construction and
  verification, legacy raw inventory audit, and exact path/hash map comparison.
- RawJournal.cs: byte-preserving block writer, independent disk audit and record recovery.
- Invoke-IOAudit.ps1: VerifyManifest, BuildManifest, AuditRaw, AuditJournal.
- Complete-IOArchive.ps1: raw audit, manifest construction and a SEPARATE complete
  final hash pass. Numerical/BF aggregate checks belong to the calling runner.
- RawJournal.ps1: thin adapter for the future runner's one physical-call recorder.
- Test-IOAudit.ps1 and Benchmark-IOAudit.ps1: isolated metadata fixtures and real-data benchmarks.

Windows PowerShell 5.1 and PowerShell 7 are supported. No additional package or
terminal compiler is required. Import-IOAudit.ps1 compiles handwritten C# as a
host helper with Add-Type. Source hashes prevent reusing a stale loaded type;
start a fresh PowerShell process after changing C# source.

## Existing sealed archives: read only

```powershell
& ./tools/io-audit-v2/Invoke-IOAudit.ps1 `
  -Operation VerifyManifest -RootDirectory $PWD `
  -ManifestPath tests/embeddingtrain32-v11/artifact-hashes.json `
  -SealPath tests/embeddingtrain32-v11/artifact-seal.json `
  -ReportPath tests/my-new-host-audit.json
```

Every declared file gets its full SHA256 checked. The seal, manifest count,
normalized unique paths, path containment and hash shape are checked first.
Legacy manifests/seals are accepted without changing their bytes. Manifest rows
are streamed into compact hash jobs, without PowerShell objects for every row.
Four workers are the default; Workers accepts 1..16. File readers deny concurrent
write/delete access while hashing. A failure cannot emit PASS.

AuditRaw accepts DataDirectory and an explicit Inventories array. It preserves
the old scope: all input/output hashes, three unique paths per origin, presence
of a regular metadata file and exact Kind counts. It does not retroactively
claim coverage of older legacy launchers absent from those inventories.

BuildManifest accepts DataDirectory, ManifestPath, SealPath and optional explicit
ExcludedPaths. Outputs must be new. Manifest order is ordinal and deterministic;
JSON is compact and streamed to disk. Its own manifest/seal/partial are excluded.
Other exclusions must be declared by the caller. Outputs/reports outside the data
directory avoid self-inclusion. CompareManifests compares every normalized path
and exact SHA, independent of JSON formatting/order. Reparse entries are refused
during enumeration. Contracted archive files must remain immutable after sealing.

## NEW raw journals

```powershell
. ./tools/io-audit-v2/RawJournal.ps1
$journal = New-TartarusRawJournal -Directory tests/new-run/bf-raw/training
try {
  # The future runner supplies ready [byte[]] input and unmodified raw output.
  # Record AFTER a physical launcher call; never again for a cache hit.
  [void](Add-TartarusRawOrigin -Journal $journal -Source $source `
    -Phase training -Kind fresh -InputBytes $payload -OutputBytes $raw)
  $capture = $journal.Complete()
} finally { $journal.Dispose() }
```

The adapter owns no launcher or cache. The new runner must have exactly one owner
of physical dispatch/origins; do not nest the old wrapper inside a second recorder.
Logical requests/cache hits and physical origins remain separate counters.

A journal is a new directory containing block-NNNNNN.bin, block-NNNNNN.jsonl,
and journal-seal.json. Each index row records Id, Source, Phase, Kind, input/output
offsets, lengths and SHA256. Ready bytes are concatenated verbatim into .bin:
no ASCII conversion, newline transformation, framing change or Base64 expansion.
All 256 byte values, including 0/26/128/255, are valid storage data.

Defaults: 64 MiB or 10000 origins per block, flush buffers after each origin.
One oversized origin gets a dedicated block and is never truncated/split.
Origin IDs are contiguous from zero within each journal. An input/output pair
is one physical origin. Index text is UTF-8; it contains routing metadata only.

Complete flushes blocks, hashes complete data/index files and publishes the
closed seal last. It means capture completion, not numerical success. A controlled
failed preflight may seal its captured bytes while keeping its numerical FAIL.
Dispose without Complete preserves partial files and never creates a seal.
The auditor refuses unsealed/incomplete captures. Reopening/appending/overwriting
an existing journal is deliberately unsupported; create a fresh run directory.

AuditJournal checks seal counts, unique direct-child regular files, whole data
and index SHA256, each origin's two SHA256 values, ID order, contiguous offsets,
full byte coverage, exact per-block/total origin counts, and absence of untracked
files/directories. Hashing and record reading use held read-only handles.
ReadOrigin returns exact input/output bytes plus routing fields and verifies the
target block/index and both payload hashes; it is not a substitute for a full audit.

## Complete a NEW host archive

```powershell
& ./tools/io-audit-v2/Complete-IOArchive.ps1 `
  -RootDirectory $PWD -DataDirectory tests/new-run -Mode BlockJournal `
  -Journals @('bf-raw/boundaries','bf-raw/training') `
  -ReportPath tests/new-run-host-finalization.json
```

For old-layout NEW captures use Mode LegacyRaw with explicit Inventories.
The entry point refuses existing outputs before writing; it cannot replace a
frozen stage archive in place. It writes raw-integrity-v2.json BEFORE building
the manifest, includes that proof, and then rereads/hashes every bound file in a
separate final guard. Its final report and console log must stay OUTSIDE sealed
data. No new data writes are allowed after the guard in the calling runner.
PASS here certifies host integrity only; BF ledger credit remains unchanged.

## Progress and proofs

ProgressEvery defaults to 25000 items; ProgressSeconds defaults to 10 seconds.
Timer heartbeats also cover long operations with no completed item yet.
Each phase emits START/WORK/DONE or FAIL, count/total and elapsed time. Unknown
totals are shown as '?'. Successful reports contain every phase's count, duration
and completion state; failures contain FAIL, the request and error, with phase
progress in the console log. Console progress does not contaminate PassThru result objects.
Set both progress options to zero for silent fixture tests.

Every test/benchmark creates a unique tests/io-audit-v2 directory and copies its
source revision there first. Failures are retained. No BF/model executions or
numerical ledger additions occur. Warm and cold file-cache timings differ greatly;
benchmark ordering and phase times must accompany speed claims.

User-facing results and proof locations: ../../IO-AUDIT-V2.md.
