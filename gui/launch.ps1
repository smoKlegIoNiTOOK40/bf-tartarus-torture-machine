$ErrorActionPreference='Stop'
try { & "$PSScriptRoot/app.ps1" }
catch {
    $diagnostics=Join-Path $PSScriptRoot ('startup-error-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N')+'.log')
    $_ | Out-String | Set-Content -LiteralPath $diagnostics -Encoding UTF8
    Add-Type -AssemblyName PresentationFramework
    [void][Windows.MessageBox]::Show(('Не удалось открыть Tartarus. Подробности сохранены здесь:'+[Environment]::NewLine+$diagnostics),'Tartarus',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    exit 1
}
