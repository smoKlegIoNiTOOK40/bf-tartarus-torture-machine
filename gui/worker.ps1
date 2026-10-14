param([Parameter(Mandatory=$true)][string]$RequestPath)
$ErrorActionPreference='Stop'
$guiRoot=$PSScriptRoot
$projectRoot=Split-Path -Parent $guiRoot
$requestDirectory=Split-Path -Parent ([IO.Path]::GetFullPath($RequestPath))
$clock=[Diagnostics.Stopwatch]::StartNew()
$result=@{Status='error';Message='Не удалось запустить модель.';ErrorKind='runtime'}

function WriteGuiProgress([string]$message) {
    [IO.File]::WriteAllText("$requestDirectory/progress.txt",$message,[Text.UTF8Encoding]::new($false))
}

try {
    $request=Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($request.Prompt -isnot [string] -or $request.Prompt.Length -gt 98 -or
        $request.Prompt -cnotmatch '^[a-z]+( [a-z]+)*$') {
        $result.ErrorKind='format'
        throw 'Используй строчные английские буквы и один пробел между словами. Максимум — 98 символов.'
    }
    if (@('crossfit','resubstitution','who','copy8') -cnotcontains $request.Arm -or
        $request.RunName -cnotmatch '^gui-[a-f0-9]{32}$') { throw 'Invalid GUI request framing' }

    $historyPath=[string]$request.HistoryContextPath
    if(-not [string]::IsNullOrEmpty($historyPath)){
        $sessionRoot=[IO.Path]::GetFullPath((Split-Path -Parent $requestDirectory)).TrimEnd('\')
        if($request.Arm -cne 'copy8' -or -not [IO.Path]::GetFullPath($historyPath).StartsWith($sessionRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'History outside current GUI session'}
    }
    WriteGuiProgress $(if($request.Arm -in @('who','copy8')){'Tartarus отвечает и проверяет результат…'}else{'Tartarus продолжает фразу и проверяет результат…'})
    $engineDirectory=Join-Path $requestDirectory 'engine'
    $demoFailure=$null
    try {
        if($request.Arm -ceq 'copy8') {
            & "$projectRoot/release/wordqa-copy8-v1/demo.ps1" -Prompt $request.Prompt -HistoryContextPath $historyPath -OutputDirectory $engineDirectory -ArchiveRoot $projectRoot *> "$requestDirectory/engine.log"
        } elseif($request.Arm -ceq 'who') {
            & "$projectRoot/release/wordqa-who-v1/demo.ps1" -Prompt $request.Prompt -OutputDirectory $engineDirectory -ArchiveRoot $projectRoot *> "$requestDirectory/engine.log"
        } else {
            & "$guiRoot/engine.ps1" -Prompt $request.Prompt -Arm $request.Arm -OutputDirectory $engineDirectory *> "$requestDirectory/engine.log"
        }
    } catch { $demoFailure=$_ }
    if ($null -ne $demoFailure) {
        if ($demoFailure.Exception.Message -match 'unknown or ambiguous word|canonical word layout') {
            $result.ErrorKind='vocabulary'
            throw 'В этой фразе есть незнакомое слово. Выбери слова из списка слева.'
        }
        if($demoFailure.Exception.Message -match 'Copy8 history'){
            $result.ErrorKind='history'
            throw 'Не удалось проверить память беседы. Нажми «Новая беседа» и начни заново.'
        }
        throw $demoFailure
    }
    $status=Get-Content -LiteralPath "$engineDirectory/run-status.json" -Raw | ConvertFrom-Json
    if ($status.NumericalStatus -cne 'PASS' -or $status.SourceStatus -cne 'PASS') { throw 'The public demo did not pass its guards' }
    $native=[IO.File]::ReadAllBytes("$engineDirectory/native.text")
    $stitched=[IO.File]::ReadAllBytes("$engineDirectory/stitched.raw")
    $stop=switch ($native[$native.Length-6]) { 69 {'eos'} 76 {'limit'} 82 {'refused'} default { throw 'Invalid native stop flag' } }
    if($stop -ceq 'refused'){$result.ErrorKind='model';throw 'Не получилось выбрать ответ. Начни новую беседу и попробуй пример слева.'}
    # Display byte-preserved model output. No host token lookup or prediction.
    $text=[Text.Encoding]::UTF8.GetString($stitched)
    if (-not $text.StartsWith($request.Prompt,[StringComparison]::Ordinal)) { throw 'Output lost its raw prompt prefix' }
    $continuation=$text.Substring($request.Prompt.Length)
    $displayText=if($request.Arm -in @('who','copy8')){$request.Prompt+[Environment]::NewLine+$continuation.TrimStart([char]' ')}else{$text}
    $result=@{Status='ok';Prompt=$request.Prompt;Arm=$request.Arm;Text=$displayText;RawText=$text;
        Continuation=$continuation;Stop=$stop;EngineDirectory=$engineDirectory}
    if($request.Arm -ceq 'copy8'){
        $result.HistoryContextPath=Join-Path $engineDirectory 'final-history.context'
        $result.HistoryUsed=-not [string]::IsNullOrEmpty($historyPath)
    }
} catch {
    $result.Message=$_.Exception.Message
    $_ | Out-String | Set-Content -LiteralPath "$requestDirectory/error.log" -Encoding UTF8
} finally {
    $clock.Stop()
    $result.ElapsedMilliseconds=$clock.ElapsedMilliseconds
    $temporaryResult=Join-Path $requestDirectory 'result.tmp'
    [IO.File]::WriteAllText($temporaryResult,(ConvertTo-Json $result -Depth 5),[Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporaryResult,(Join-Path $requestDirectory 'result.json'))
}
if ($result.Status -cne 'ok') { exit 1 }
