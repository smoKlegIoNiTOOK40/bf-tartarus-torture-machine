param([switch]$VisualOnly)
$ErrorActionPreference='Stop'
$testDirectory=Join-Path $PSScriptRoot ('checks/'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDirectory)
$testChecks=[Collections.Generic.List[string]]::new()
$testFailure=$null
function AssertGui([bool]$condition,[string]$name) {
    if (-not $condition) { throw ('FAIL: '+$name) }
    $testChecks.Add($name)
    Write-Output ('PASS: '+$name)
}
function PumpGui([int]$milliseconds=50) {
    $frame=[Windows.Threading.DispatcherFrame]::new()
    $pumpTimer=[Windows.Threading.DispatcherTimer]::new()
    $pumpTimer.Interval=[TimeSpan]::FromMilliseconds($milliseconds)
    $stopPump={ $frame.Continue=$false; $pumpTimer.Stop() }.GetNewClosure()
    $pumpTimer.Add_Tick($stopPump); $pumpTimer.Start()
    [Windows.Threading.Dispatcher]::PushFrame($frame)
}
function ClickGui($button) {
    $button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
}
function WaitGuiResult {
    $deadline=[DateTime]::UtcNow.AddMinutes(4)
    while ($null -ne $script:GuiState.Worker) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'GUI test worker timeout' }
        PumpGui 100
    }
    return $script:GuiState.LastResult
}
function SaveGuiImage([string]$name) {
    $script:GuiWindow.UpdateLayout()
    $visual=$script:GuiWindow.Content
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$visual.ActualWidth,[int]$visual.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($visual)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new()
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $testDirectory $name))
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}
function StartGuiHeldFixture {
    $directory=Join-Path $testDirectory ('held-'+[Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($directory)
    $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSScriptRoot+'\fixtures\hold-worker.ps1" -Directory "'+$directory+'"'
    $script:GuiState.Worker=[Tartarus.Gui.OwnedWorker]::new("$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe",$arguments,$PSScriptRoot)
    $script:GuiState.RequestDirectory=$directory
    $script:GuiState.Prompt='mira opens'; $script:GuiState.Arm='crossfit'
    $script:GuiState.Deadline=[DateTime]::UtcNow.AddMinutes(2)
    SetGuiBusy $true
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path -LiteralPath "$directory/child.pid")) {
        if ([DateTime]::UtcNow -gt $deadline -or $script:GuiState.Worker.Process.HasExited) { throw 'Held BF fixture did not start' }
        PumpGui 50
    }
    $childId=[int](Get-Content -LiteralPath "$directory/child.pid" -Raw)
    AssertGui (@($script:GuiState.Worker.GetProcessIds()) -contains $childId) 'owned job includes the live ordinary BF child'
    return $childId
}
try {
    . "$PSScriptRoot/app.ps1" -NoShow
    $script:GuiControls.ArmBox.SelectedIndex=0
    $script:GuiWindow.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual
    $script:GuiWindow.Left=-12000; $script:GuiWindow.Top=0
    $script:GuiWindow.Show(); PumpGui 100
    AssertGui ($script:GuiControls.VocabularyPanel.Children.Count -eq 27) 'actual bundled vocabulary is visible'
    AssertGui ($script:GuiControls.ExamplesPanel.Children.Count -eq 4) 'four examples are available'
    SaveGuiImage 'welcome.png'
    if ($VisualOnly) {
        $contentHost=$script:GuiControls.PromptBox.Template.FindName('PART_ContentHost',$script:GuiControls.PromptBox)
        AssertGui ($contentHost.ViewportHeight -ge 20) 'input text has a full visible line'
        $script:GuiWindow.Width=940; $script:GuiWindow.Height=690; PumpGui 100
        SaveGuiImage 'minimum-size.png'
        AssertGui ($contentHost.ViewportHeight -ge 20) 'input text remains visible at minimum size'
        $script:GuiControls.ArmBox.IsDropDownOpen=$true; PumpGui 100
        AssertGui ($script:GuiControls.ArmBox.IsDropDownOpen) 'model picker opens'
        $script:GuiControls.ArmBox.SelectedIndex=1; $script:GuiControls.ArmBox.IsDropDownOpen=$false
        AssertGui ($script:GuiControls.ArmDescription.Text.Contains('хуже')) 'model picker updates the description'
        return
    }

    $script:GuiControls.PromptBox.Text=''
    ClickGui $script:GuiControls.SendButton
    AssertGui ($null -eq $script:GuiState.Worker) 'empty input starts no worker'
    $script:GuiControls.PromptBox.Text='mira opens; whoami'
    ClickGui $script:GuiControls.SendButton
    AssertGui ($null -eq $script:GuiState.Worker) 'noncanonical input starts no worker'
    $script:GuiControls.PromptBox.Text='a'*99
    ClickGui $script:GuiControls.SendButton
    AssertGui ($null -eq $script:GuiState.Worker) 'overlong input starts no worker'
    $script:GuiControls.PromptBox.Text='mira'
    $openWord=@($script:GuiControls.VocabularyPanel.Children | Where-Object {$_.Tag -ceq 'opens'})[0]
    ClickGui $openWord
    AssertGui ($script:GuiControls.PromptBox.Text -ceq 'mira opens') 'word buttons append plain text'

    ClickGui $script:GuiControls.ExamplesPanel.Children[0]
    ClickGui $script:GuiControls.SendButton
    $firstWorker=$script:GuiState.Worker
    $firstProcessId=$firstWorker.Process.Id
    AssertGui ($null -ne $firstWorker -and -not $script:GuiControls.SendButton.IsEnabled -and $script:GuiControls.StopButton.Visibility -eq [Windows.Visibility]::Visible) 'generation runs in background with stop available'
    ClickGui $script:GuiControls.SendButton
    AssertGui ([object]::ReferenceEquals($firstWorker,$script:GuiState.Worker)) 'double submit cannot start another worker'
    $response=WaitGuiResult
    AssertGui ($response.Status -ceq 'ok' -and $response.Text -ceq 'mira opens a small red bag' -and $response.Continuation -ceq ' a small red bag' -and $response.Stop -ceq 'eos') 'GUI receives real primary BF output and EOS'
    AssertGui (-not (Get-Process -Id $firstProcessId -ErrorAction SilentlyContinue)) 'finished worker is gone'
    AssertGui (Test-Path -LiteralPath "$($response.EngineDirectory)/native.text") 'native output and archive are retained'
    SaveGuiImage 'primary.png'

    ClickGui $script:GuiControls.ExamplesPanel.Children[3]
    ClickGui $script:GuiControls.SendButton
    $response=WaitGuiResult
    AssertGui ($response.Status -ceq 'ok' -and $response.Text -ceq 'oren rests near a small red bench') 'second prompt reaches the real model independently'
    SaveGuiImage 'history.png'
    $script:GuiWindow.Width=940; $script:GuiWindow.Height=690; PumpGui 100
    SaveGuiImage 'minimum-size.png'
    AssertGui ($script:GuiControls.PromptBox.ActualWidth -gt 300 -and $script:GuiControls.SendButton.ActualWidth -gt 100) 'composer remains usable at minimum window size'
    $script:GuiWindow.Width=1130; $script:GuiWindow.Height=820; PumpGui 50

    $script:GuiControls.ArmBox.SelectedIndex=1
    ClickGui $script:GuiControls.ExamplesPanel.Children[0]
    ClickGui $script:GuiControls.SendButton
    $response=WaitGuiResult
    AssertGui ($response.Status -ceq 'ok' -and $response.Text -ceq 'mira opens' -and $response.Continuation -ceq '' -and $response.Stop -ceq 'eos') 'control model can return genuine immediate EOS'

    $script:GuiControls.ArmBox.SelectedIndex=0
    $script:GuiControls.PromptBox.Text='mira dances'
    ClickGui $script:GuiControls.SendButton
    $response=WaitGuiResult
    AssertGui ($response.Status -ceq 'error' -and $response.ErrorKind -ceq 'vocabulary') 'BF unknown-word rejection is shown as a friendly error'
    AssertGui ($script:GuiControls.SendButton.IsEnabled) 'input becomes usable after an error'

    # Short numerical BF processes may finish between observations. Use a
    # deliberately held ordinary BF process to verify cancellation deterministically.
    $heldResult=@(StartGuiHeldFixture)
    $childId=[int]$heldResult[-1]
    $cancelProcessId=$script:GuiState.Worker.Process.Id
    AssertGui ((Get-Process -Id $childId).ProcessName -ceq 'qdb') 'cancellation fixture uses the real BF interpreter'
    ClickGui $script:GuiControls.StopButton
    PumpGui 150
    AssertGui ($script:GuiState.LastResult.Status -ceq 'cancelled' -and $null -eq $script:GuiState.Worker) 'stop returns the UI to ready state'
    AssertGui (-not (Get-Process -Id $cancelProcessId -ErrorAction SilentlyContinue)) 'stop terminates the owned worker'
    AssertGui (-not (Get-Process -Id $childId -ErrorAction SilentlyContinue)) 'stop terminates the owned BF child'
    AssertGui (Test-Path -LiteralPath "$($script:GuiState.LastResult.RequestDirectory)/cancelled.json") 'cancelled attempt is preserved'

    ClickGui $script:GuiControls.ClearButton
    AssertGui ($script:GuiControls.HistoryPanel.Children.Count -eq 1 -and $script:GuiControls.WelcomeCard.Visibility -eq [Windows.Visibility]::Visible) 'clear restores welcome without deleting saved runs'
    AssertGui (Test-Path -LiteralPath "$($script:GuiState.SessionDirectory)/history.jsonl") 'history remains on disk'

    $heldResult=@(StartGuiHeldFixture)
    $closingChildId=[int]$heldResult[-1]
    $closingProcessId=$script:GuiState.Worker.Process.Id
    $script:GuiWindow.Close(); PumpGui 100
    AssertGui ($null -eq $script:GuiState.Worker -and -not (Get-Process -Id $closingProcessId -ErrorAction SilentlyContinue)) 'closing the window terminates its active worker'
    AssertGui (-not (Get-Process -Id $closingChildId -ErrorAction SilentlyContinue)) 'closing the window terminates its BF child'
} catch { $testFailure=$_; $_ | Out-String | Set-Content -LiteralPath "$testDirectory/failure.log" -Encoding UTF8 }
finally {
    if ($null -ne $script:GuiState -and $null -ne $script:GuiState.Worker) { StopGuiGeneration }
    if ($null -ne $script:GuiTimer) { $script:GuiTimer.Stop() }
    if ($null -ne $script:GuiWindow -and $script:GuiWindow.IsVisible) { $script:GuiWindow.Close() }
    [IO.File]::WriteAllText("$testDirectory/report.json",(ConvertTo-Json @{Status=$(if ($null -eq $testFailure) {'PASS'} else {'FAIL'});Checks=$testChecks.ToArray();SessionDirectory=$script:GuiState.SessionDirectory} -Depth 5),[Text.UTF8Encoding]::new($false))
    Write-Output ('Report: '+$testDirectory)
}
if ($null -ne $testFailure) { throw $testFailure }
