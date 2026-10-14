param([ValidateRange(1,16)][int]$Workers=4,[ValidateSet('Stage70','Stage71')][string]$Target='Stage70',[string]$GuardProofPath='')
# Real sealed data is read only. New benchmark outputs and packed copies are isolated.
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runDirectory=Join-Path $projectRoot ('tests/io-audit-v2/benchmark-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
$sourceDirectory=Join-Path $runDirectory source
[void][IO.Directory]::CreateDirectory($sourceDirectory)
$sourceHashes=@{}
foreach ($sourceFile in Get-ChildItem -LiteralPath $PSScriptRoot -File) {
 Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $sourceDirectory $sourceFile.Name)
 $sourceHashes[$sourceFile.Name]=(Get-FileHash -LiteralPath $sourceFile.FullName).Hash
}
$protectedPaths=@('SOURCE-RULES.md','tests/embeddingtrain32-v11/artifact-seal.json','tests/embeddingtrain32-v11/selected.weights','training/embeddingtrain32-v11/source-seal.json','WORDTRAIN32-PLAN.stage71.md','EMBEDDING-HEAD32-PLAN.stage71.md')
$before=@{};foreach($path in $protectedPaths){$before[$path]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash}
$proof=[ordered]@{Status='FAIL';Target=$Target;Sources=$sourceHashes;ProtectedBefore=$before;PowerShell=$PSVersionTable.PSVersion.ToString();Workers=$Workers;ModelArithmetic=$false;BFExecutions=0}
$clock=[Diagnostics.Stopwatch]::StartNew()
try {
 . (Join-Path $sourceDirectory Import-IOAudit.ps1)
 $invoke=Join-Path $sourceDirectory Invoke-IOAudit.ps1
 if($Target -ceq 'Stage70') {
  $dataDirectory=Join-Path $projectRoot 'tests/generalization32-v11';$bindings=42550;$origins=12349;$rawFiles=37047
  $expectedSHA='D547FE50A25A7C056131FE054AACF883C2339A69FAA3827B8C7FBC7DD9E2FC74'
  $inventories=[string[]]@('boundaries','overlap','evaluation','conflicts','regressions','source-controls','aggregate' | ForEach-Object {$_+'.origins70.json'})
 } else {
  $dataDirectory=Join-Path $projectRoot 'tests/embeddingtrain32-v11';$bindings=752754;$origins=195765;$rawFiles=587295
  $expectedSHA='E40B4445299F06AB1F84906B85FD6E91DEB05749C21BAE91B03770C5A12269DF'
  $inventories=[string[]]@('boundaries','training','regressions','source-controls','aggregate' | ForEach-Object {$_+'.origins71.json'})
 }
 if($GuardProofPath) {
  $guardProof=Get-Content -LiteralPath $GuardProofPath -Raw|ConvertFrom-Json
  if($guardProof.Status -cne 'PASS' -or $guardProof.SourceRevision -cne $ioAuditRevision){throw 'Benchmark prior guard proof/source mismatch'}
  $proof.Guard=$guardProof.Result;$proof.GuardProofPath=[IO.Path]::GetFullPath($GuardProofPath)
 } else {
  $proof.Guard=& $invoke -Operation VerifyManifest -RootDirectory $projectRoot -ManifestPath (Join-Path $dataDirectory artifact-hashes.json) -SealPath (Join-Path $dataDirectory artifact-seal.json) -Workers $Workers -PassThru
 }
 if($proof.Guard.Status -cne 'PASS' -or $proof.Guard.Bindings -ne $bindings -or $proof.Guard.SHA256 -cne $expectedSHA){throw 'Benchmark sealed archive mismatch'}
 $proof.Raw=& $invoke -Operation AuditRaw -RootDirectory $projectRoot -DataDirectory $dataDirectory -Inventories $inventories -Workers $Workers -PassThru
 if($proof.Raw.Origins -ne $origins -or $proof.Raw.UniqueRawFiles -ne $rawFiles -or $proof.Raw.Kinds.fresh -ne $origins){throw 'Benchmark raw coverage mismatch'}
 $packed=Join-Path $runDirectory packed-raw
 $proof.Packed=[Tartarus.IOAuditV2.Journals]::PackLegacy($dataDirectory,$inventories,$packed,67108864,10000,25000,10)
 $proof.BlockAudit=& $invoke -Operation AuditJournal -RootDirectory $projectRoot -DataDirectory $packed -Workers $Workers -PassThru
 if($proof.BlockAudit.Origins -ne $origins -or $proof.BlockAudit.Kinds.fresh -ne $origins){throw 'Benchmark block origin coverage mismatch'}
 $first=[Tartarus.IOAuditV2.Journals]::ReadOrigin($packed,0)
 $firstOld=Get-Content -LiteralPath (Join-Path $dataDirectory $inventories[0]) -Raw | ConvertFrom-Json
 $firstOld=$firstOld[0]
 if(-not [Tartarus.IOAuditV2.Files]::Same($first.Input,[IO.File]::ReadAllBytes($firstOld.InputPath)) -or -not [Tartarus.IOAuditV2.Files]::Same($first.Output,[IO.File]::ReadAllBytes($firstOld.OutputPath))){throw 'Benchmark recovered record mismatch'}
 $proof.FirstRecordExact=$true
 $newManifest=Join-Path $runDirectory artifact-hashes.json;$newSeal=Join-Path $runDirectory artifact-seal.json
 $proof.Build=& $invoke -Operation BuildManifest -RootDirectory $projectRoot -DataDirectory $dataDirectory -ManifestPath $newManifest -SealPath $newSeal -ExcludedPaths @((Join-Path $dataDirectory artifact-hashes.json),(Join-Path $dataDirectory artifact-seal.json)) -Workers $Workers -PassThru
 $proof.EquivalentManifestBindings=[Tartarus.IOAuditV2.Files]::CompareManifests($projectRoot,(Join-Path $dataDirectory artifact-hashes.json),$newManifest)
 if($proof.EquivalentManifestBindings -ne $bindings){throw 'Benchmark rebuilt manifest coverage mismatch'}
 $proof.RebuiltGuard=& $invoke -Operation VerifyManifest -RootDirectory $projectRoot -ManifestPath $newManifest -SealPath $newSeal -Workers $Workers -PassThru
 $after=@{};foreach($path in $protectedPaths){$after[$path]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash;if($after[$path] -cne $before[$path]){throw ('Protected stage71 changed: '+$path)}}
 $proof.ProtectedAfter=$after;$proof.Frozen71Changed=$false;$proof.Status='PASS'
} finally {
 $clock.Stop();$proof.ElapsedMilliseconds=$clock.ElapsedMilliseconds
 [IO.File]::WriteAllText((Join-Path $runDirectory benchmark.json),(ConvertTo-Json -InputObject $proof -Depth 15),[Text.UTF8Encoding]::new($false))
 Write-Host ('{0} host benchmark; {1}' -f $proof.Status,(Join-Path $runDirectory benchmark.json))
}
