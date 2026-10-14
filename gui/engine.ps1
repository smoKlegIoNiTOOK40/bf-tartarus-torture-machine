# Host adapter to the immutable Word 80 snapshot. Numerical helpers stay unchanged.
param([Parameter(Mandatory=$true)][string]$Prompt,
      [ValidateSet('crossfit','resubstitution')][string]$Arm='crossfit',
      [Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$guiEngineWorkspace=Split-Path -Parent $PSScriptRoot
$guiEngineSnapshot=Join-Path $guiEngineWorkspace 'release/wordbackoff80-v1'
$guiEngineOutput=[IO.Path]::GetFullPath($OutputDirectory)
if (-not $guiEngineOutput.StartsWith(([IO.Path]::GetFullPath("$PSScriptRoot/runs")+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase) -and
    -not $guiEngineOutput.StartsWith(([IO.Path]::GetFullPath("$PSScriptRoot/checks")+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)) { throw 'GUI engine output must stay inside runs or checks' }
if (Test-Path -LiteralPath $guiEngineOutput) { throw 'Preserve previous engine attempt; choose a new output directory' }
[void][IO.Directory]::CreateDirectory($guiEngineOutput)
$env:TARTARUS75_OUT=$guiEngineOutput
. "$guiEngineSnapshot/runtime.ps1"
GuardPortable80
$guiEngineManifestSHA=(Get-FileHash -LiteralPath "$guiEngineSnapshot/bundle-files.json").Hash
$guiEngineBindings=Get-Content -LiteralPath "$guiEngineSnapshot/bundle-files.json" -Raw | ConvertFrom-Json
# These helpers set root to the snapshot and data to the per-request directory.
foreach ($guiEngineHelper in (Get-Content -LiteralPath "$guiEngineSnapshot/runtime-helpers.json" -Raw | ConvertFrom-Json)) { . "$guiEngineSnapshot/$guiEngineHelper" }
$script:guiEngineSources=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($guiEngineBinding in $guiEngineBindings) {
    $script:guiEngineSources[[IO.Path]::GetFullPath("$guiEngineSnapshot/$($guiEngineBinding.Path)")]=$guiEngineBinding.SHA256
}
$script:guiEngineChecked=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:guiEngineOriginalRun=${function:Run75}
function Run75($relative,[byte[]]$payload,[switch]$Uncached) {
    $guiSourcePath=[Tartarus.IOAuditV2.Files]::Within($root,$relative)
    if (-not $script:guiEngineSources.ContainsKey($guiSourcePath)) { throw 'BF source is not in the frozen snapshot' }
    if ($script:guiEngineChecked.Add($guiSourcePath) -and (Get-FileHash -LiteralPath $guiSourcePath).Hash -cne $script:guiEngineSources[$guiSourcePath]) { throw 'Frozen BF source changed before execution' }
    return ,(& $script:guiEngineOriginalRun $relative $payload -Uncached:$Uncached)
}
Json75 source-revision.json @{Format='shared-snapshot-v1';Directory=$guiEngineSnapshot;ManifestSHA256=$guiEngineManifestSHA;ArchivedBeforeBF=$true;Credit=0}
# Preserve the small adapter itself before numerical execution.
[IO.File]::Copy($PSCommandPath,"$data/engine-adapter.ps1",$false)
$guiEngineAdapterSHA=(Get-FileHash -LiteralPath "$data/engine-adapter.ps1").Hash
$guiEngineFailure=$null
try {
    $guiRawPrompt=[Text.Encoding]::UTF8.GetBytes($Prompt); Save75 prompt.raw $guiRawPrompt
    Json75 prompt-input-seal.json @{SHA256=(Get-FileHash "$data/prompt.raw").Hash;ArchivedBeforeBF=$true;Arm=$Arm;Budget=99;Credit=0}
    Phase75 gui-word80 {
        $guiRecords=RecordsWord78 prompt $guiRawPrompt
        $guiContext=Slice75 $guiRecords ($guiRecords.Length-10) 8
        $guiPrefix=if ($Arm -ceq 'resubstitution') {'resub-selected'} else {'selected'}
        $guiModel=LoadModelPortable80 "$root/model" $guiPrefix
        $guiPayload=PayloadBackoffGen80 $guiModel $guiContext (Bytes75 '99')
        $guiOutput=Run75 'training/wordbackoffgen32-v1/text.bf' $guiPayload
        if ($guiOutput.Length -lt 7) { throw 'GUI word output framing' }
        $guiTail=$guiOutput.Length-7
        CheckC76 'gui80 word separator/guard' (Bytes75 '|1') (Join75 @((Slice75 $guiOutput $guiTail 1),(Slice75 $guiOutput ($guiTail+6) 1)))
        if ($guiOutput[$guiTail+1] -notin @(69,76)) { throw 'GUI stop flag domain' }
        Save75 native.text $guiOutput; Save75 native.input $guiPayload
        Save75 stitched.raw (Join75 @($guiRawPrompt,(Slice75 $guiOutput 0 $guiTail)))
        Json75 run.json @{Arm=$Arm;Prompt=$Prompt;Budget=99;Credit=0;ModelArithmetic='handwritten BF';Storage='shared-snapshot-v1'}
    }
} catch { $guiEngineFailure=$_; Json75 host-error.json @{Message=$_.Exception.Message;NumericalPass=$false} }
$guiEngineSourceStatus='FAIL'
try {
    GuardPortable80
    if ((Get-FileHash -LiteralPath "$root/bundle-files.json").Hash -cne $guiEngineManifestSHA) { throw 'Snapshot revision changed during generation' }
    if ((Get-FileHash -LiteralPath $PSCommandPath).Hash -cne $guiEngineAdapterSHA) { throw 'GUI adapter changed during generation' }
    $guiEngineSourceStatus='PASS'
    Json75 source-routing.json @{Status='PASS';SnapshotDirectory=$root;ManifestSHA256=$guiEngineManifestSHA;Sources=@($script:guiEngineChecked | Sort-Object);ArchivedBeforeBF=$true;ModelArithmetic='handwritten BF'}
} catch { Json75 source-error.json @{Message=$_.Exception.Message;NumericalPass=$false}; if ($null -eq $guiEngineFailure) { $guiEngineFailure=$_ } }
Json75 run-status.json @{NumericalStatus=$(if ($null -eq $guiEngineFailure) {'PASS'} else {'FAIL'});SourceStatus=$guiEngineSourceStatus;Credit=0;Storage='shared-snapshot-v1'}
$guiEngineProof=& "$root/tools/io-audit-v2/Complete-IOArchive.ps1" -RootDirectory $guiEngineWorkspace -DataDirectory $data -Mode BlockJournal -Journals $script:journals75.ToArray() -ReportPath ($guiEngineOutput+'-host.json') -PassThru
if ($guiEngineProof.Status -cne 'PASS') { throw 'GUI raw/artifact archive proof required' }
if ($null -ne $guiEngineFailure) { throw $guiEngineFailure }
