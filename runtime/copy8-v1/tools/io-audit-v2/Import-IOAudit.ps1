# Load handwritten C# host metadata helpers; no BF/model code or execution.
$ErrorActionPreference='Stop'
$ioAuditSources=@('MetadataJson.cs','FileAudit.cs','RawJournal.cs') | ForEach-Object { Join-Path $PSScriptRoot $_ }
$ioAuditRevision=($ioAuditSources | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) -join ':'
if ('Tartarus.IOAuditV2.Files' -as [type]) {
 if ($global:TartarusIOAuditV2Revision -cne $ioAuditRevision) { throw 'IO audit source changed; start a fresh PowerShell process' }
} else {
 Add-Type -Path $ioAuditSources
 $global:TartarusIOAuditV2Revision=$ioAuditRevision
}
