$ErrorActionPreference='Stop'
$output=Join-Path (Split-Path -Parent $PSScriptRoot) 'Tartarus.exe'
if (Test-Path -LiteralPath $output) { throw 'Tartarus.exe already exists; preserve it before building another launcher.' }
Add-Type -Path "$PSScriptRoot/Launcher.cs" -OutputAssembly $output -OutputType WindowsApplication -ReferencedAssemblies 'System.dll','System.Windows.Forms.dll'
Write-Output $output
