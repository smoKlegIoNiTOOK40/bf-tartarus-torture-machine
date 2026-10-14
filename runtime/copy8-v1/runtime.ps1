$ErrorActionPreference='Stop';$copyRuntimeRoot=$PSScriptRoot
. "$copyRuntimeRoot/tools/io-audit-v2/Import-IOAudit.ps1"
function GuardCopySnapshot {[void][Tartarus.IOAuditV2.Files]::VerifyManifest($copyRuntimeRoot,"$copyRuntimeRoot/bundle-files.json","$copyRuntimeRoot/bundle-seal.json",4,25000,10)}
function LoadCopyModel {
 $model=@{Kind='copy';Weights=[IO.File]::ReadAllBytes("$copyRuntimeRoot/model/selected.weights");FeatureLabels=[IO.File]::ReadAllBytes("$copyRuntimeRoot/model/selected.feature.labels");FineLabels=[IO.File]::ReadAllBytes("$copyRuntimeRoot/model/selected.fine.labels");BigramLabels=[IO.File]::ReadAllBytes("$copyRuntimeRoot/model/selected.bigram.labels")}
 if($model.Weights.Length -ne 324 -or $model.FeatureLabels.Length -ne 450 -or $model.FineLabels.Length -ne 4096 -or $model.BigramLabels.Length -ne 32){throw 'Copy8 model packet framing'};return $model
}
function LoadCopyHistory([string]$path,[string]$archiveRoot,[string]$modelManifestSHA){
 try{
  $history=[Tartarus.IOAuditV2.Files]::Within($archiveRoot,$path)
  if([IO.Path]::GetFileName($history) -cne 'final-history.context'){throw 'Unexpected history artifact'}
  $parent=Split-Path -Parent $history
  [void][Tartarus.IOAuditV2.Files]::VerifyManifest($archiveRoot,"$parent/artifact-hashes.json","$parent/artifact-seal.json",4,25000,10)
  $bindings=Get-Content -LiteralPath "$parent/artifact-hashes.json" -Raw|ConvertFrom-Json
  $bound=@($bindings|Where-Object {[Tartarus.IOAuditV2.Files]::Within($archiveRoot,$_.Path) -ceq $history})
  if($bound.Count -ne 1){throw 'History is not bound in the prior archive'}
  $status=Get-Content -LiteralPath "$parent/run-status.json" -Raw|ConvertFrom-Json
  $revision=Get-Content -LiteralPath "$parent/source-revision.json" -Raw|ConvertFrom-Json
  $run=Get-Content -LiteralPath "$parent/run.json" -Raw|ConvertFrom-Json
  if($status.NumericalStatus -cne 'PASS' -or $status.SourceStatus -cne 'PASS' -or $revision.Model -cne 'copy8-v1' -or $revision.ManifestSHA256 -cne $modelManifestSHA -or $run.Stop -cnotin @('E','L')){throw 'History model/status mismatch'}
  $bytes=[IO.File]::ReadAllBytes($history);if($bytes.Length -ne 16){throw 'History byte framing'}
  return ,$bytes
 }catch{throw ('Copy8 history verification failed: '+$_.Exception.Message)}
}
