param(
 [Parameter(Mandatory=$true)][string]$RootDirectory,
 [Parameter(Mandatory=$true)][string]$DataDirectory,
 [Parameter(Mandatory=$true)][ValidateSet('LegacyRaw','BlockJournal')][string]$Mode,
 [string[]]$Inventories=@(),
 [string[]]$Journals=@(),
 [Parameter(Mandatory=$true)][string]$ReportPath,
 [ValidateRange(1,16)][int]$Workers=4,
 [ValidateRange(0,2147483647)][int]$ProgressEvery=25000,
 [ValidateRange(0,3600)][int]$ProgressSeconds=10,
 [switch]$PassThru
)
# NEW archive host finalization only. Numerical/BF aggregate checks belong to the calling runner.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot Import-IOAudit.ps1)
$ioRoot=[Tartarus.IOAuditV2.Files]::Root($RootDirectory)
$ioData=[Tartarus.IOAuditV2.Files]::Within($ioRoot,$DataDirectory)
$ioReport=[Tartarus.IOAuditV2.Files]::Within($ioRoot,$ReportPath)
if ($ioReport.StartsWith($ioData+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive report/log must be outside sealed data' }
$ioManifest=Join-Path $ioData artifact-hashes.json
$ioSeal=Join-Path $ioData artifact-seal.json
$ioRawProof=Join-Path $ioData raw-integrity-v2.json
foreach ($path in @($ioManifest,$ioSeal,$ioRawProof,$ioReport)) {
 if (Test-Path -LiteralPath $path) { throw ('Archive output already exists: '+$path) }
}
$ioClock=[Diagnostics.Stopwatch]::StartNew()
$ioProof=[ordered]@{Status='FAIL';Mode=$Mode;RootDirectory=$ioRoot;DataDirectory=$ioData;ManifestPath=$ioManifest;SealPath=$ioSeal;Inventories=$Inventories;Journals=$Journals;RawAudits=@();SourceRevision=$ioAuditRevision;WrapperSHA256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;Workers=$Workers;ModelArithmetic=$false;BFExecutions=0}
try {
 $audits=[Collections.Generic.List[object]]::new()
 if ($Mode -ceq 'LegacyRaw') {
  $audits.Add([Tartarus.IOAuditV2.Files]::AuditRaw($ioRoot,$ioData,$Inventories,$Workers,$ProgressEvery,$ProgressSeconds))
 } else {
  if ($Journals.Count -eq 0) { throw 'Archive journals required' }
  $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($journal in $Journals) {
   $journalPath=[Tartarus.IOAuditV2.Files]::Within($ioData,$journal)
   if (-not $seen.Add($journalPath)) { throw 'Archive duplicate journal' }
   $audits.Add([Tartarus.IOAuditV2.Journals]::Audit($ioRoot,$journalPath,$Workers,$ProgressEvery,$ProgressSeconds))
  }
 }
 $ioProof.RawAudits=$audits.ToArray()
 [Tartarus.IOAuditV2.Files]::WriteNew($ioRawProof,(ConvertTo-Json -InputObject $ioProof.RawAudits -Depth 12))
 $ioProof.Build=[Tartarus.IOAuditV2.Files]::BuildManifest($ioRoot,$ioData,$ioManifest,$ioSeal,[string[]]@(),$Workers,$ProgressEvery,$ProgressSeconds)
 $ioProof.Guard=[Tartarus.IOAuditV2.Files]::VerifyManifest($ioRoot,$ioManifest,$ioSeal,$Workers,$ProgressEvery,$ProgressSeconds)
 $ioProof.Status='PASS'
} catch { $ioProof.Error=$_.Exception.Message;throw }
finally {
 $ioClock.Stop();$ioProof.ElapsedMilliseconds=$ioClock.ElapsedMilliseconds
 [Tartarus.IOAuditV2.Files]::WriteNew($ioReport,(ConvertTo-Json -InputObject $ioProof -Depth 15))
}
if ($PassThru) { [pscustomobject]$ioProof } else { 'PASS host archive: {0} files, {1}ms' -f $ioProof.Guard.Bindings,$ioProof.ElapsedMilliseconds }
