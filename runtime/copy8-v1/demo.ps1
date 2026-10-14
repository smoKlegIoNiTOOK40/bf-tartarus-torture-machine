param([Parameter(Mandatory=$true)][string]$Prompt,[string]$HistoryContextPath,[string]$OutputDirectory,[string]$ArchiveRoot)
$ErrorActionPreference='Stop';$copyPublicSnapshot=$PSScriptRoot
if([string]::IsNullOrEmpty($ArchiveRoot)){$ArchiveRoot=$copyPublicSnapshot}
$copyPublicArchiveRoot=[IO.Path]::GetFullPath($ArchiveRoot).TrimEnd('\')
if([string]::IsNullOrEmpty($OutputDirectory)){$OutputDirectory=Join-Path $copyPublicSnapshot ('runs/copy-'+[Guid]::NewGuid().ToString('N'))}
$copyPublicOutput=[IO.Path]::GetFullPath($OutputDirectory)
if(-not $copyPublicOutput.StartsWith($copyPublicArchiveRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Copy8 output outside declared archive root'}
if(Test-Path -LiteralPath $copyPublicOutput){throw 'Preserve previous Copy8 request'}
. "$copyPublicSnapshot/runtime.ps1";GuardCopySnapshot
$copyPublicManifestSHA=(Get-FileHash -LiteralPath "$copyPublicSnapshot/bundle-files.json").Hash
$copyPublicRows=Get-Content -LiteralPath "$copyPublicSnapshot/bundle-files.json" -Raw|ConvertFrom-Json
$env:TARTARUS75_OUT=$copyPublicOutput
foreach($helper in (Get-Content -LiteralPath "$copyPublicSnapshot/runtime-helpers.json" -Raw|ConvertFrom-Json)){. "$copyPublicSnapshot/$helper"}
$script:copyPublicSources=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase);$script:copyPublicChecked=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($binding in $copyPublicRows){$script:copyPublicSources[[IO.Path]::GetFullPath("$copyPublicSnapshot/$($binding.Path)")]=$binding.SHA256}
$script:copyPublicOriginalRun=${function:Run75}
function Run75($relative,[byte[]]$payload,[switch]$Uncached){
 $source=[Tartarus.IOAuditV2.Files]::Within($copyPublicSnapshot,$relative)
 if(-not $script:copyPublicSources.ContainsKey($source)){throw ('Copy8 unbound BF source '+$relative)}
 if($script:copyPublicChecked.Add($source) -and (Get-FileHash -LiteralPath $source).Hash -cne $script:copyPublicSources[$source]){throw 'Copy8 source changed before first BF use'}
 return ,(& $script:copyPublicOriginalRun $relative $payload -Uncached:$Uncached)
}
Json75 source-revision.json @{Format='shared-snapshot-v1';Directory=$copyPublicSnapshot;ManifestSHA256=$copyPublicManifestSHA;ArchivedBeforeBF=$true;Model='copy8-v1';PerRequestSourceCopy=$false;GoalComplete=$false}
$copyPublicFailure=$null
try{
 Save75 prompt.raw ([Text.Encoding]::UTF8.GetBytes($Prompt));Json75 prompt-input-seal.json @{SHA256=(Get-FileHash -LiteralPath "$data/prompt.raw").Hash;OperationalCallCap=7;ArchivedBeforeBF=$true;HistorySource=$HistoryContextPath}
 Phase75 copy-public {
  if([string]::IsNullOrEmpty($HistoryContextPath)){$context=QuestionContextCopyLearn8 prompt ([IO.File]::ReadAllBytes("$data/prompt.raw"))}else{
   $history=LoadCopyHistory $HistoryContextPath $copyPublicArchiveRoot $copyPublicManifestSHA
   foreach($slot in (PartsRef76 $history 2)){CheckC76 'Copy8 history slot domain' (Bytes75 '0') (Run75 'training/abi32-v11/validate-slot.bf' $slot)}
   Save75 history-input.context $history;Json75 history-input-origin.json @{Path=$HistoryContextPath;SHA256=(Get-FileHash -LiteralPath $HistoryContextPath).Hash;ActualPriorArtifactVerified=$true;GoldHistoryUsed=$false}
   $context=AppendUserCopyLearn8 prompt $history ([IO.File]::ReadAllBytes("$data/prompt.raw"))
  }
  Save75 input.context $context;$generated=GenerateCopyLearn8 answer (LoadCopyModel) $context
  Save75 native.text ([IO.File]::ReadAllBytes("$data/answer.text"));Save75 native.trace $generated.Trace;Save75 answer.raw $generated.Text;Save75 final-history.context $generated.Context
  Save75 stitched.raw (Join75 @(([IO.File]::ReadAllBytes("$data/prompt.raw")),$generated.Text))
  Json75 run.json @{Model='copy8-v1';Prompt=$Prompt;Stop=$generated.Reason;HistoryUsed=(-not [string]::IsNullOrEmpty($HistoryContextPath));HistoryExcludesEOS=$true;ModelArithmetic='handwritten BF';Scope='explicit fact plus question tag; short linked turns';Storage='shared-snapshot-v1';GoalComplete=$false}
 }
}catch{$copyPublicFailure=$_;Json75 host-error.json @{Message=$_.Exception.Message;ScriptStackTrace=$_.ScriptStackTrace;NumericalPass=$false}}
$copyPublicSourceStatus='PASS'
try{GuardCopySnapshot;if((Get-FileHash -LiteralPath "$copyPublicSnapshot/bundle-files.json").Hash -cne $copyPublicManifestSHA){throw 'Copy8 snapshot revision changed'};Json75 source-routing.json @{Status='PASS';ArchivedBeforeBF=$true;ManifestSHA256=$copyPublicManifestSHA;Sources=@($script:copyPublicChecked|Sort-Object)}}catch{$copyPublicSourceStatus='FAIL';Json75 source-error.json @{Message=$_.Exception.Message};if($null -eq $copyPublicFailure){$copyPublicFailure=$_}}
Json75 run-status.json @{NumericalStatus=$(if($null -eq $copyPublicFailure){'PASS'}else{'FAIL'});SourceStatus=$copyPublicSourceStatus;Model='copy8-v1';GoalComplete=$false}
$copyPublicProof=& "$copyPublicSnapshot/tools/io-audit-v2/Complete-IOArchive.ps1" -RootDirectory $copyPublicArchiveRoot -DataDirectory $data -Mode BlockJournal -Journals $script:journals75.ToArray() -ReportPath ($copyPublicOutput+'-host.json') -PassThru
if($copyPublicProof.Status -cne 'PASS'){throw 'Copy8 raw/artifact verification required'}
if($null -ne $copyPublicFailure){throw $copyPublicFailure}
[Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes("$data/answer.raw"))
