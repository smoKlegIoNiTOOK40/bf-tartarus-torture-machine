param(
 [Parameter(Mandatory=$true)][ValidateSet('VerifyManifest','BuildManifest','AuditRaw','AuditJournal')][string]$Operation,
 [Parameter(Mandatory=$true)][string]$RootDirectory,
 [string]$DataDirectory='',
 [string]$ManifestPath='',
 [string]$SealPath='',
 [string[]]$Inventories=@(),
 [string[]]$ExcludedPaths=@(),
 [ValidateRange(1,16)][int]$Workers=4,
 [ValidateRange(0,2147483647)][int]$ProgressEvery=25000,
 [ValidateRange(0,3600)][int]$ProgressSeconds=10,
 [string]$ReportPath='',
 [switch]$PassThru
)
# Host files/SHA/routing metadata only. Never launches BF or numerical checks.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Import-IOAudit.ps1')
$ioAuditResult=$null
$ioAuditRequest=[ordered]@{Operation=$Operation;RootDirectory=[IO.Path]::GetFullPath($RootDirectory);DataDirectory=$DataDirectory;ManifestPath=$ManifestPath;SealPath=$SealPath;Inventories=$Inventories;ExcludedPaths=$ExcludedPaths;Workers=$Workers;ProgressEvery=$ProgressEvery;ProgressSeconds=$ProgressSeconds}
if ($ReportPath -and (Test-Path -LiteralPath $ReportPath)) { throw 'IO audit report already exists' }
try {
 switch ($Operation) {
  'VerifyManifest' { $ioAuditResult=[Tartarus.IOAuditV2.Files]::VerifyManifest($RootDirectory,$ManifestPath,$SealPath,$Workers,$ProgressEvery,$ProgressSeconds) }
  'BuildManifest' { $ioAuditResult=[Tartarus.IOAuditV2.Files]::BuildManifest($RootDirectory,$DataDirectory,$ManifestPath,$SealPath,$ExcludedPaths,$Workers,$ProgressEvery,$ProgressSeconds) }
  'AuditRaw' { $ioAuditResult=[Tartarus.IOAuditV2.Files]::AuditRaw($RootDirectory,$DataDirectory,$Inventories,$Workers,$ProgressEvery,$ProgressSeconds) }
  'AuditJournal' { $ioAuditResult=[Tartarus.IOAuditV2.Journals]::Audit($RootDirectory,$DataDirectory,$Workers,$ProgressEvery,$ProgressSeconds) }
 }
 if ($ReportPath) {
  $ioAuditProof=[ordered]@{Status='PASS';Request=$ioAuditRequest;Result=$ioAuditResult;SourceRevision=$ioAuditRevision;WrapperSHA256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;PowerShell=$PSVersionTable.PSVersion.ToString();ModelArithmetic=$false;BFExecutions=0}
  [Tartarus.IOAuditV2.Files]::WriteNew([IO.Path]::GetFullPath($ReportPath),(ConvertTo-Json -InputObject $ioAuditProof -Depth 12))
 }
 if ($PassThru) { $ioAuditResult } else { 'PASS {0}: files={1}, origins={2}, elapsed={3}ms' -f $Operation,$ioAuditResult.Bindings,$ioAuditResult.Origins,$ioAuditResult.ElapsedMilliseconds }
} catch {
 if ($ReportPath -and -not(Test-Path -LiteralPath $ReportPath)) {
  $ioAuditFailure=[ordered]@{Status='FAIL';Operation=$Operation;Request=$ioAuditRequest;Error=$_.Exception.Message;SourceRevision=$ioAuditRevision;WrapperSHA256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;ModelArithmetic=$false;BFExecutions=0}
  [Tartarus.IOAuditV2.Files]::WriteNew([IO.Path]::GetFullPath($ReportPath),(ConvertTo-Json -InputObject $ioAuditFailure -Depth 5))
 }
 throw
}
