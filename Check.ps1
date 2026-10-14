param()
# Source/model byte verification only; no host model arithmetic or BF execution.
$ErrorActionPreference='Stop'
$snapshot=Join-Path $PSScriptRoot 'runtime/copy8-v1'
. "$snapshot/tools/io-audit-v2/Import-IOAudit.ps1"
[void][Tartarus.IOAuditV2.Files]::VerifyManifest($snapshot,"$snapshot/bundle-files.json","$snapshot/bundle-seal.json",4,25000,10)
Write-Output 'PASS: sealed Copy8 runtime and learned model bytes match.'
