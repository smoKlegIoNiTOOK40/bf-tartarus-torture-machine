# Lifecycle fixture only: run ordinary qdb on a handwritten nonterminating loop.
# The GUI's owned job must terminate both this worker and its BF child.
param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop'
$fixtureGuiRoot=Split-Path -Parent $PSScriptRoot
$fixtureProjectRoot=Split-Path -Parent $fixtureGuiRoot
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=Join-Path $fixtureProjectRoot 'release/wordbackoff80-v1/tools/qdb/qdb.exe'
$start.Arguments='"'+(Join-Path $PSScriptRoot 'hold.bf')+'"'
$start.UseShellExecute=$false; $start.CreateNoWindow=$true
$held=[Diagnostics.Process]::Start($start)
[IO.File]::WriteAllText((Join-Path $Directory 'child.pid'),$held.Id.ToString())
$held.WaitForExit()
exit $held.ExitCode
