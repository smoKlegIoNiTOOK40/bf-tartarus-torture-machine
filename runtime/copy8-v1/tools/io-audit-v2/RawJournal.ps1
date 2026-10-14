# Thin adapter for NEW future runners. Caller owns launching/caching; record each physical call once.
. (Join-Path $PSScriptRoot 'Import-IOAudit.ps1')
function New-TartarusRawJournal {
 param([Parameter(Mandatory=$true)][string]$Directory,[long]$BlockBytes=67108864,[int]$BlockOrigins=10000,[int]$FlushEvery=1)
 return [Tartarus.IOAuditV2.RawJournalWriter]::new([IO.Path]::GetFullPath($Directory),$BlockBytes,$BlockOrigins,$FlushEvery)
}
function Add-TartarusRawOrigin {
 param([Parameter(Mandatory=$true)]$Journal,[string]$Source,[string]$Phase,[string]$Kind,[byte[]]$InputBytes,[byte[]]$OutputBytes)
 return $Journal.Append($Source,$Phase,$Kind,$InputBytes,$OutputBytes)
}
function Close-TartarusRawJournal {
 param([Parameter(Mandatory=$true)]$Journal)
 try { return $Journal.Complete() } finally { $Journal.Dispose() }
}
