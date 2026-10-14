param([switch]$NoShow)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
if (-not ('Tartarus.Gui.OwnedWorker' -as [type])) { Add-Type -Path "$PSScriptRoot/OwnedWorker.cs" }
$script:GuiRoot=$PSScriptRoot
$script:GuiWindow=[Windows.Markup.XamlReader]::Parse((Get-Content -LiteralPath "$PSScriptRoot/window.xaml" -Raw -Encoding UTF8))
$script:GuiWindow.Add_SourceInitialized({
    try { [Tartarus.Gui.WindowAppearance]::UseDarkTitleBar([Windows.Interop.WindowInteropHelper]::new($script:GuiWindow).Handle) } catch { }
})
$script:GuiControls=@{}
foreach ($controlName in 'ArmBox','ArmDescription','ExamplesPanel','VocabularyPanel','ClearButton','HistoryScroll','HistoryPanel','WelcomeCard','BusyBar','StatusText','PromptBox','LengthText','StopButton','SendButton','ModelTitle','ModelDetails','ExamplesTitle','ScopeNote','IntroTitle','IntroDescription','WelcomeTitle','WelcomeDescription','WelcomeExample','WelcomeLegend','EnterHint','FollowupPanel','AskWhatButton','AskWhereButton') {
    $script:GuiControls[$controlName]=$script:GuiWindow.FindName($controlName)
}
$script:GuiState=[pscustomobject]@{
    Worker=$null; RequestDirectory=$null; Prompt=$null; Arm=$null; Deadline=$null
    LastResult=$null; MemoryPath=$null; History=[Collections.Generic.List[object]]::new()
    SessionDirectory=(Join-Path $script:GuiRoot ('runs/session-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N')))
}

function GuiBrush([string]$color) { return [Windows.Media.BrushConverter]::new().ConvertFromString($color) }
function SetGuiStatus([string]$text,[string]$color='#A6A4B4') {
    $script:GuiControls.StatusText.Text=$text
    $script:GuiControls.StatusText.Foreground=GuiBrush $color
}
function SetGuiBusy([bool]$busy) {
    $script:GuiControls.SendButton.IsEnabled=-not $busy
    $script:GuiControls.PromptBox.IsEnabled=-not $busy
    $script:GuiControls.ArmBox.IsEnabled=-not $busy
    $script:GuiControls.ExamplesPanel.IsEnabled=-not $busy
    $script:GuiControls.VocabularyPanel.IsEnabled=-not $busy
    $script:GuiControls.ClearButton.IsEnabled=-not $busy
    $script:GuiControls.FollowupPanel.IsEnabled=-not $busy
    $visibility=if ($busy) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $script:GuiControls.BusyBar.Visibility=$visibility
    $script:GuiControls.StopButton.Visibility=$visibility
}
function ResetGuiMemory {
    $script:GuiState.MemoryPath=$null
    $script:GuiControls.FollowupPanel.Visibility=[Windows.Visibility]::Collapsed
}
function NewGuiText([string]$text,[double]$size,[string]$color) {
    $block=[Windows.Controls.TextBlock]::new()
    $block.Text=$text; $block.FontSize=$size; $block.Foreground=GuiBrush $color
    $block.TextWrapping=[Windows.TextWrapping]::Wrap
    return $block
}
function AddGuiResult($result) {
    $script:GuiState.LastResult=$result
    $script:GuiState.History.Add($result)
    $script:GuiControls.WelcomeCard.Visibility=[Windows.Visibility]::Collapsed
    $card=[Windows.Controls.Border]::new()
    $card.Background=GuiBrush '#1B1B23'; $card.CornerRadius=[Windows.CornerRadius]::new(12)
    $card.Padding=[Windows.Thickness]::new(21); $card.Margin=[Windows.Thickness]::new(0,0,0,16)
    $stack=[Windows.Controls.StackPanel]::new(); $card.Child=$stack
    $isQuestion=$result.Arm -in @('who','copy8')
    $armName=if ($result.Arm -ceq 'copy8') { 'Диалог · 8 слов' } elseif ($isQuestion) { 'Who v1' } elseif ($result.Arm -ceq 'resubstitution') { 'Word 80 · сравнение' } else { 'Word 80 · основная' }
    $label=NewGuiText ('TARTARUS  /  '+$armName) 11 '#FFAA98'
    $label.Margin=[Windows.Thickness]::new(0,0,0,14); [void]$stack.Children.Add($label)
    $phrase=[Windows.Controls.TextBlock]::new(); $phrase.FontSize=22
    $phrase.TextWrapping=[Windows.TextWrapping]::Wrap; $phrase.LineHeight=32
    $prefix=[Windows.Documents.Run]::new([string]$result.Prompt); $prefix.Foreground=GuiBrush '#9691A6'
    [void]$phrase.Inlines.Add($prefix)
    if ($result.Status -ceq 'ok') {
        if($isQuestion){[void]$phrase.Inlines.Add([Windows.Documents.LineBreak]::new())}
        $shownContinuation=if($isQuestion){([string]$result.Continuation).TrimStart([char]' ')}else{[string]$result.Continuation}
        $continuation=[Windows.Documents.Run]::new($shownContinuation)
        $continuation.Foreground=GuiBrush '#F1F0F5'; [void]$phrase.Inlines.Add($continuation)
    }
    [void]$stack.Children.Add($phrase)
    $metadata=''
    if ($result.Status -ceq 'ok') {
        $metadata=if ($result.Stop -ceq 'limit') { 'Достигнут предел генерации' } elseif($isQuestion) { 'Ответ завершён' } else { 'Завершил фразу' }
        if ([string]::IsNullOrEmpty($result.Continuation)) { $metadata='Модель завершила запуск без новых слов' }
        if ($result.Arm -ceq 'copy8' -and $result.HistoryUsed) { $metadata+=' · с памятью беседы' }
        $metadata+=' · '+([Math]::Round($result.ElapsedMilliseconds/1000,1)).ToString()+' с'
    } else { $metadata=$result.Message }
    $meta=NewGuiText $metadata 12 $(if ($result.Status -ceq 'error') { '#FFAA98' } else { '#A6A4B4' })
    $meta.Margin=[Windows.Thickness]::new(0,14,0,0); [void]$stack.Children.Add($meta)
    $actions=[Windows.Controls.WrapPanel]::new(); $actions.Margin=[Windows.Thickness]::new(0,14,0,0)
    if ($result.Status -ceq 'ok') {
        $copy=[Windows.Controls.Button]::new(); $copy.Content='Скопировать'; $copy.Style=$script:GuiWindow.Resources['SmallButton']
        $copy.Tag=[string]$result.Text
        $copy.Add_Click({ param($sender,$eventArgs)
            try { [Windows.Clipboard]::SetText([string]$sender.Tag); SetGuiStatus 'Текст скопирован' '#9CD8B7' }
            catch { SetGuiStatus 'Не удалось скопировать. Попробуй ещё раз.' '#FFAA98' }
        })
        [void]$actions.Children.Add($copy)
    }
    if ($result.RequestDirectory) {
        $files=[Windows.Controls.Button]::new(); $files.Content='Файлы запуска'; $files.Style=$script:GuiWindow.Resources['SmallButton']
        $files.Margin=[Windows.Thickness]::new(8,0,0,0); $files.Tag=[string]$result.RequestDirectory
        $files.Add_Click({ param($sender,$eventArgs)
            Start-Process -FilePath "$env:SystemRoot/explorer.exe" -ArgumentList ('"'+[string]$sender.Tag+'"')
        })
        [void]$actions.Children.Add($files)
    }
    [void]$stack.Children.Add($actions)
    [void]$script:GuiControls.HistoryPanel.Children.Add($card)
    $script:GuiControls.HistoryScroll.ScrollToEnd()
    try {
        [void][IO.Directory]::CreateDirectory($script:GuiState.SessionDirectory)
        [IO.File]::AppendAllText((Join-Path $script:GuiState.SessionDirectory 'history.jsonl'),((ConvertTo-Json $result -Compress -Depth 5)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    } catch { SetGuiStatus 'Результат показан, но историю не удалось сохранить.' '#FFAA98' }
}
function SaveGuiWorkerConsole {
    $worker=$script:GuiState.Worker
    if ($null -eq $worker) { return }
    try {
        [IO.File]::WriteAllText((Join-Path $script:GuiState.RequestDirectory 'worker.stdout.log'),$worker.StandardOutput.GetAwaiter().GetResult(),[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $script:GuiState.RequestDirectory 'worker.stderr.log'),$worker.StandardError.GetAwaiter().GetResult(),[Text.UTF8Encoding]::new($false))
    } catch { }
}
function FinishGuiWorker {
    $worker=$script:GuiState.Worker
    if ($null -eq $worker -or -not $worker.Process.HasExited) { return }
    SaveGuiWorkerConsole
    try {
        $resultPath=Join-Path $script:GuiState.RequestDirectory 'result.json'
        if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Worker exited without a result' }
        $result=Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($worker.Process.ExitCode -ne 0 -and $result.Status -ceq 'ok') { throw 'Worker exit disagrees with the result' }
        if ($result.Status -cnotin @('ok','error')) { throw 'Invalid worker result status' }
        if ($result.Status -ceq 'error' -and $result.ErrorKind -ceq 'runtime') {
            $result.Message='Не удалось завершить запуск. Подробности сохранены в файлах запуска.'
        }
    } catch {
        $result=[pscustomobject]@{Status='error';Message='Не удалось получить результат. Подробности сохранены в файлах запуска.'}
    }
    $result | Add-Member -NotePropertyName Prompt -NotePropertyValue $script:GuiState.Prompt -Force
    $result | Add-Member -NotePropertyName Arm -NotePropertyValue $script:GuiState.Arm -Force
    $result | Add-Member -NotePropertyName RequestDirectory -NotePropertyValue $script:GuiState.RequestDirectory -Force
    $worker.Dispose(); $script:GuiState.Worker=$null
    SetGuiBusy $false
    if ($result.Status -ceq 'ok') {
        if($result.Arm -ceq 'copy8') {
            $script:GuiState.MemoryPath=[string]$result.HistoryContextPath
            $script:GuiControls.FollowupPanel.Visibility=[Windows.Visibility]::Visible
            $script:GuiControls.PromptBox.Text=''
        }
        SetGuiStatus 'Готов к следующему вводу' '#9CD8B7'
    }
    else { SetGuiStatus $result.Message '#FFAA98' }
    AddGuiResult $result
    [void]$script:GuiControls.PromptBox.Focus()
}
function StopGuiGeneration([string]$message='Запуск остановлен. Частичные файлы сохранены.') {
    $worker=$script:GuiState.Worker
    if ($null -eq $worker) { return }
    if ($worker.Process.HasExited) { FinishGuiWorker; return }
    $worker.Cancel()
    [void]$worker.Process.WaitForExit(5000)
    SaveGuiWorkerConsole
    $worker.Dispose(); $script:GuiState.Worker=$null
    $result=[pscustomobject]@{Status='cancelled';Prompt=$script:GuiState.Prompt;Arm=$script:GuiState.Arm;Message=$message;RequestDirectory=$script:GuiState.RequestDirectory}
    [IO.File]::WriteAllText((Join-Path $script:GuiState.RequestDirectory 'cancelled.json'),(ConvertTo-Json $result),[Text.UTF8Encoding]::new($false))
    SetGuiBusy $false; SetGuiStatus $message; AddGuiResult $result
}
function StartGuiGeneration {
    if ($null -ne $script:GuiState.Worker) { return }
    $prompt=$script:GuiControls.PromptBox.Text
    if ([string]::IsNullOrWhiteSpace($prompt)) { SetGuiStatus 'Введи текст или выбери пример слева.' '#FFAA98'; return }
    if ($prompt.Length -gt 98 -or $prompt -cnotmatch '^[a-z]+( [a-z]+)*$') {
        SetGuiStatus 'Нужны строчные английские слова и один пробел между ними.' '#FFAA98'; return
    }
    $arm=[string]$script:GuiControls.ArmBox.SelectedItem.Tag
    $runName='gui-'+[Guid]::NewGuid().ToString('N')
    $requestDirectory=Join-Path $script:GuiState.SessionDirectory $runName
    try {
        [void][IO.Directory]::CreateDirectory($requestDirectory)
        $requestPath=Join-Path $requestDirectory 'request.json'
        $historyPath=if($arm -ceq 'copy8'){[string]$script:GuiState.MemoryPath}else{''}
        [IO.File]::WriteAllText($requestPath,(ConvertTo-Json @{Prompt=$prompt;Arm=$arm;RunName=$runName;HistoryContextPath=$historyPath}),[Text.UTF8Encoding]::new($false))
        $arguments='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$script:GuiRoot+'\worker.ps1" -RequestPath "'+$requestPath+'"'
        $worker=[Tartarus.Gui.OwnedWorker]::new("$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe",$arguments,$script:GuiRoot)
        $script:GuiState.Worker=$worker; $script:GuiState.RequestDirectory=$requestDirectory
        $script:GuiState.Prompt=$prompt; $script:GuiState.Arm=$arm
        $script:GuiState.LastResult=$null; $script:GuiState.Deadline=[DateTime]::UtcNow.AddMinutes(5)
        SetGuiBusy $true; SetGuiStatus 'Запускаю Tartarus…' '#FFAA98'
    } catch { SetGuiStatus ('Не удалось запустить окно модели: '+$_.Exception.Message) '#FFAA98' }
}

function SetGuiModel {
    ResetGuiMemory
    $isCopy=[string]$script:GuiControls.ArmBox.SelectedItem.Tag -ceq 'copy8'
    $isQuestion=[string]$script:GuiControls.ArmBox.SelectedItem.Tag -ceq 'who'
    $script:GuiControls.ModelTitle.Text=if($isQuestion){'Who v1'}else{'Word 80'}
    $script:GuiControls.ModelDetails.Text=if($isQuestion){'30 слов · контекст из 4 слов'}else{'27 слов · контекст из 4 слов'}
    $script:GuiControls.ArmDescription.Text=if($isQuestion){'Первый обученный опыт: короткий вопрос о персонаже и ответ именем.'}elseif($script:GuiControls.ArmBox.SelectedIndex -eq 0){'Выбрана по переносу между учебными группами.'}else{'Сильнее подогнана под учебные тексты. Может продолжать хуже.'}
    $script:GuiControls.ExamplesTitle.Text=if($isQuestion){'ПОПРОБУЙ ВОПРОС'}else{'ПОПРОБУЙ НАЧАЛО'}
    $script:GuiControls.ScopeNote.Text=if($isQuestion){'Ищет имя по признаку предмета: red, blue, green или small. Вопросы what/where и память беседы пока не обучены.'}else{'Продолжает короткие английские фразы. Для вопросов выбери Who v1.'}
    $script:GuiControls.IntroTitle.Text=if($isQuestion){'Кто это?'}else{'Продолжим фразу?'}
    $script:GuiControls.IntroDescription.Text=if($isQuestion){'Каждый вопрос — отдельный запуск. История пока не передаётся модели.'}else{'Каждый запуск начинается с твоего ввода.'}
    $script:GuiControls.WelcomeTitle.Text=if($isQuestion){'Задай первый вопрос.'}else{'Первая фраза — твоя.'}
    $script:GuiControls.WelcomeDescription.Text=if($isQuestion){'Выбери пример или составь похожий вопрос из слов слева. Модель обучена отвечать именами mira, noah, lina и oren.'}else{'Введи начало из слов слева. Tartarus выберет продолжение и решит, где закончить.'}
    $script:GuiControls.WelcomeExample.Text=if($isQuestion){'who carries a red book'}else{'mira opens …'}
    $script:GuiControls.WelcomeLegend.Text=if($isQuestion){'Серый текст — вопрос. Светлый — ответ модели.'}else{'Серый текст — твой ввод. Светлый — продолжение модели.'}
    $script:GuiControls.EnterHint.Text=if($isQuestion){'Enter — спросить'}else{'Enter — продолжить'}
    $script:GuiControls.SendButton.Content=if($isQuestion){'Спросить →'}else{'Продолжить →'}
    $script:GuiControls.ClearButton.Content='Очистить'
    $script:GuiControls.ClearButton.ToolTip='Очистить историю в окне. Файлы запусков сохранятся.'
    if($isCopy){
        $script:GuiControls.ModelTitle.Text='Диалог'
        $script:GuiControls.ModelDetails.Text='30 слов · память из 8 слов'
        $script:GuiControls.ArmDescription.Text='Обученные ответы о персонаже, предмете и месте. Помнит предыдущий ответ.'
        $script:GuiControls.ExamplesTitle.Text='НАЧНИ С ФАКТА'
        $script:GuiControls.ScopeNote.Text='Сначала факт и вопрос who, what или where в конце. Затем короткий второй вопрос what или where. Для другого факта выбери пример или начни новую беседу. Свободная речь пока не обучена.'
        $script:GuiControls.IntroTitle.Text='Кто, что и где?'
        $script:GuiControls.IntroDescription.Text='Задай факт, получи ответ и спроси ещё раз с учётом памяти.'
        $script:GuiControls.WelcomeTitle.Text='Начнём маленькую беседу.'
        $script:GuiControls.WelcomeDescription.Text='Выбери факт слева. После ответа попробуй what или where — предыдущий ответ попадёт в память модели.'
        $script:GuiControls.WelcomeExample.Text='mira carries a red key who'
        $script:GuiControls.WelcomeLegend.Text='Серый текст — твой вопрос. Светлый — ответ модели.'
        $script:GuiControls.EnterHint.Text='Enter — спросить'
        $script:GuiControls.SendButton.Content='Спросить →'
        $script:GuiControls.ClearButton.Content='Новая беседа'
        $script:GuiControls.ClearButton.ToolTip='Начать с пустой памятью и очистить окно. Файлы прежних запусков сохранятся.'
    }
    $script:GuiControls.ExamplesPanel.Children.Clear()
    $examples=if($isCopy){@('mira carries a red key who','noah finds the blue box what','lina rests under the green lamp where','oren rests near the bench who')}elseif($isQuestion){@('who carries a red book','who finds a blue door','who carries the green bench','who finds the small book')}else{@('mira opens','noah finds','lina closes','oren rests')}
foreach ($example in $examples) {
    $button=[Windows.Controls.Button]::new(); $button.Content=$example
    $button.Tag=$example; $button.HorizontalContentAlignment=[Windows.HorizontalAlignment]::Left
    $button.Margin=[Windows.Thickness]::new(0,0,0,7); $button.FontFamily=[Windows.Media.FontFamily]::new('Consolas')
    if($isQuestion -or $isCopy){$exampleText=NewGuiText $example 12 '#E5E3ED';$exampleText.FontFamily=$button.FontFamily;$button.Content=$exampleText}
    $button.Add_Click({param($sender,$eventArgs) if([string]$script:GuiControls.ArmBox.SelectedItem.Tag -ceq 'copy8'){ResetGuiMemory};$script:GuiControls.PromptBox.Text=[string]$sender.Tag; [void]$script:GuiControls.PromptBox.Focus(); $script:GuiControls.PromptBox.CaretIndex=$script:GuiControls.PromptBox.Text.Length})
    [void]$script:GuiControls.ExamplesPanel.Children.Add($button)
}
    $script:GuiControls.VocabularyPanel.Children.Clear()
$vocabularyRelative=if($isCopy){'release/wordqa-copy8-v1/training/wordqa-codec32-v1/vocabulary.json'}elseif($isQuestion){'release/wordqa-who-v1/training/wordqa-codec32-v1/vocabulary.json'}else{'release/wordbackoff80-v1/training/wordcodec32-v1/vocabulary.json'}
$vocabularyPath=Join-Path (Split-Path -Parent $script:GuiRoot) $vocabularyRelative
foreach ($row in (Get-Content -LiteralPath $vocabularyPath -Raw -Encoding UTF8 | ConvertFrom-Json)) {
    if ([string]::IsNullOrEmpty($row.Word)) { continue }
    $button=[Windows.Controls.Button]::new(); $button.Content=[string]$row.Word; $button.Tag=[string]$row.Word
    $button.Style=$script:GuiWindow.Resources['SmallButton']; $button.Margin=[Windows.Thickness]::new(0,0,5,5)
    $button.Add_Click({ param($sender,$eventArgs)
        $current=$script:GuiControls.PromptBox.Text.TrimEnd()
        $next=if ($current.Length -eq 0) { [string]$sender.Tag } else { $current+' '+[string]$sender.Tag }
        if ($next.Length -le 98) { $script:GuiControls.PromptBox.Text=$next; $script:GuiControls.PromptBox.CaretIndex=$next.Length }
        else { SetGuiStatus 'Во вводе уже нет места. Максимум — 98 символов.' '#FFAA98' }
        [void]$script:GuiControls.PromptBox.Focus()
    })
    [void]$script:GuiControls.VocabularyPanel.Children.Add($button)
}
    $script:GuiControls.PromptBox.Text=$examples[0]
    $script:GuiControls.LengthText.Text=$script:GuiControls.PromptBox.Text.Length.ToString()+' / 98 · строчные английские слова'
}
$script:GuiControls.PromptBox.Add_TextChanged({$script:GuiControls.LengthText.Text=$script:GuiControls.PromptBox.Text.Length.ToString()+' / 98 · строчные английские слова'})
$script:GuiControls.PromptBox.Add_PreviewKeyDown({param($sender,$eventArgs) if ($eventArgs.Key -eq [Windows.Input.Key]::Return) { $eventArgs.Handled=$true; StartGuiGeneration }})
$script:GuiControls.SendButton.Add_Click({StartGuiGeneration})
$script:GuiControls.StopButton.Add_Click({StopGuiGeneration})
$script:GuiControls.AskWhatButton.Add_Click({$script:GuiControls.PromptBox.Text='what';[void]$script:GuiControls.PromptBox.Focus()})
$script:GuiControls.AskWhereButton.Add_Click({$script:GuiControls.PromptBox.Text='where';[void]$script:GuiControls.PromptBox.Focus()})
$script:GuiControls.ArmBox.Add_SelectionChanged({SetGuiModel})
SetGuiModel
$script:GuiControls.ClearButton.Add_Click({
    if ($null -ne $script:GuiState.Worker) { return }
    ResetGuiMemory
    $script:GuiControls.HistoryPanel.Children.Clear()
    $script:GuiControls.WelcomeCard.Visibility=[Windows.Visibility]::Visible
    [void]$script:GuiControls.HistoryPanel.Children.Add($script:GuiControls.WelcomeCard)
    SetGuiStatus 'Память беседы и окно очищены. Файлы запусков сохранены.'
})
$script:GuiTimer=[Windows.Threading.DispatcherTimer]::new()
$script:GuiTimer.Interval=[TimeSpan]::FromMilliseconds(150)
$script:GuiTimer.Add_Tick({
    if ($null -eq $script:GuiState.Worker) { return }
    if ($script:GuiState.Worker.Process.HasExited) { FinishGuiWorker; return }
    if ([DateTime]::UtcNow -gt $script:GuiState.Deadline) { StopGuiGeneration 'Запуск занял слишком много времени и остановлен. Файлы сохранены.'; return }
    $progressPath=Join-Path $script:GuiState.RequestDirectory 'progress.txt'
    try { if (Test-Path -LiteralPath $progressPath) { SetGuiStatus (Get-Content -LiteralPath $progressPath -Raw -Encoding UTF8) '#FFAA98' } } catch { }
})
$script:GuiWindow.Add_Closed({
    $script:GuiTimer.Stop()
    if ($null -ne $script:GuiState.Worker) { StopGuiGeneration 'Окно закрыто. Незавершённый запуск остановлен.' }
})
$script:GuiTimer.Start()
if (-not $NoShow) { [void]$script:GuiWindow.ShowDialog() }
