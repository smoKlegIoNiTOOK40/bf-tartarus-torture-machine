param()
$ErrorActionPreference='Stop'
$testDirectory=Join-Path $PSScriptRoot ('checks/who-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDirectory)
$testChecks=[Collections.Generic.List[string]]::new();$testFailure=$null
function AssertWhoGui([bool]$condition,[string]$name){if(-not $condition){throw ('FAIL: '+$name)};$testChecks.Add($name);Write-Output ('PASS: '+$name)}
function PumpWhoGui([int]$milliseconds=50){
 $frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds($milliseconds)
 $stop={ $frame.Continue=$false;$timer.Stop() }.GetNewClosure();$timer.Add_Tick($stop);$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
}
function ClickWhoGui($button){$button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))}
function WaitWhoGui {
 $deadline=[DateTime]::UtcNow.AddMinutes(4)
 while($null -ne $script:GuiState.Worker){if([DateTime]::UtcNow -gt $deadline){throw 'Who GUI worker timeout'};PumpWhoGui 100}
 return $script:GuiState.LastResult
}
function SaveWhoGuiImage([string]$name){
 $script:GuiWindow.UpdateLayout();$visual=$script:GuiWindow.Content
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$visual.ActualWidth,[int]$visual.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $testDirectory $name));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
# Preserve the GUI revision before any BF worker. The numerical release is a
# separately sealed shared snapshot; this copy contains only small UI sources.
$sourceDirectory=Join-Path $testDirectory 'gui-source';[void][IO.Directory]::CreateDirectory($sourceDirectory)
$sourceRows=@(foreach($file in @('app.ps1','worker.ps1','window.xaml','OwnedWorker.cs','test-who.ps1')){
 Copy-Item -LiteralPath "$PSScriptRoot/$file" -Destination "$sourceDirectory/$file"
 @{Path=$file;SHA256=(Get-FileHash -LiteralPath "$sourceDirectory/$file").Hash}
})
[IO.File]::WriteAllText("$sourceDirectory/files.json",(ConvertTo-Json $sourceRows -Depth 4),[Text.UTF8Encoding]::new($false))
try{
 . "$PSScriptRoot/app.ps1" -NoShow
 $script:GuiControls.ArmBox.SelectedIndex=2
 $script:GuiWindow.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual;$script:GuiWindow.Left=-12000;$script:GuiWindow.Top=0;$script:GuiWindow.Show();PumpWhoGui 100
 AssertWhoGui ($script:GuiControls.ArmBox.SelectedIndex -eq 2 -and $script:GuiControls.ModelTitle.Text -ceq 'Who v1') 'trained Who remains available'
 AssertWhoGui ($script:GuiControls.VocabularyPanel.Children.Count -eq 30 -and $script:GuiControls.ExamplesPanel.Children.Count -eq 4) 'actual Who vocabulary and four questions are visible'
 AssertWhoGui ($script:GuiControls.IntroDescription.Text.Contains('не передаётся')) 'history limitation is visible'
 SaveWhoGuiImage 'welcome.png'
 $script:GuiControls.ArmBox.SelectedIndex=0;PumpWhoGui
 AssertWhoGui ($script:GuiControls.VocabularyPanel.Children.Count -eq 27 -and $script:GuiControls.ModelTitle.Text -ceq 'Word 80' -and $script:GuiControls.PromptBox.Text -ceq 'mira opens') 'legacy mode restores its vocabulary and example'
 $script:GuiControls.ArmBox.SelectedIndex=2;PumpWhoGui
 $expected=@('mira','noah','lina','oren')
 for($exampleIndex=0;$exampleIndex -lt 4;$exampleIndex++){
  ClickWhoGui $script:GuiControls.ExamplesPanel.Children[$exampleIndex]
  $question=$script:GuiControls.PromptBox.Text;ClickWhoGui $script:GuiControls.SendButton
  $worker=$script:GuiState.Worker
  AssertWhoGui ($null -ne $worker -and -not $script:GuiControls.ArmBox.IsEnabled) ('Who example '+$exampleIndex+' starts an owned background worker')
  ClickWhoGui $script:GuiControls.SendButton
  AssertWhoGui ([object]::ReferenceEquals($worker,$script:GuiState.Worker)) ('Who example '+$exampleIndex+' rejects double submission')
  $response=WaitWhoGui
  AssertWhoGui ($response.Status -ceq 'ok' -and $response.Stop -ceq 'eos' -and $response.Continuation -ceq (' '+$expected[$exampleIndex])) ('Who example '+$exampleIndex+' displays actual BF name and EOS')
  AssertWhoGui ($response.RawText -ceq ($question+' '+$expected[$exampleIndex]) -and $response.Text -ceq ($question+[Environment]::NewLine+$expected[$exampleIndex])) ('Who example '+$exampleIndex+' preserves raw output and copies separate question/answer lines')
  $engine=$response.EngineDirectory
  $status=Get-Content -LiteralPath "$engine/run-status.json" -Raw|ConvertFrom-Json
  $routing=Get-Content -LiteralPath "$engine/source-revision.json" -Raw|ConvertFrom-Json
  $proof=Get-Content -LiteralPath ($engine+'-host.json') -Raw|ConvertFrom-Json
  AssertWhoGui ($status.NumericalStatus -ceq 'PASS' -and $status.SourceStatus -ceq 'PASS' -and $proof.Status -ceq 'PASS') ('Who example '+$exampleIndex+' retains passing source and raw/artifact proof')
  AssertWhoGui ($routing.Format -ceq 'shared-snapshot-v1' -and -not $routing.PerRequestSourceCopy -and -not (Test-Path -LiteralPath "$engine/source")) ('Who example '+$exampleIndex+' reuses one source snapshot')
  $runBytes=(Get-ChildItem -LiteralPath $response.RequestDirectory -Recurse -File|Measure-Object Length -Sum).Sum
  AssertWhoGui ($runBytes -lt 1048576) ('Who example '+$exampleIndex+' request stays below one MiB')
 }
 SaveWhoGuiImage 'answers.png'
 $lastCard=$script:GuiControls.HistoryPanel.Children[$script:GuiControls.HistoryPanel.Children.Count-1]
 $inlines=@($lastCard.Child.Children[1].Inlines)
 AssertWhoGui (@($inlines|Where-Object {$_ -is [Windows.Documents.LineBreak]}).Count -eq 1) 'answer is on a separate visible line'
 $script:GuiWindow.Width=940;$script:GuiWindow.Height=690;PumpWhoGui 100
 $contentHost=$script:GuiControls.PromptBox.Template.FindName('PART_ContentHost',$script:GuiControls.PromptBox)
 AssertWhoGui ($contentHost.ViewportHeight -ge 20 -and $script:GuiControls.PromptBox.ActualWidth -gt 300) 'Who composer has a full visible line at minimum size'
 SaveWhoGuiImage 'minimum-size.png'
 $script:GuiControls.PromptBox.Text='who carries a purple book';ClickWhoGui $script:GuiControls.SendButton;$response=WaitWhoGui
 AssertWhoGui ($response.Status -ceq 'error' -and $response.ErrorKind -ceq 'vocabulary' -and $script:GuiControls.SendButton.IsEnabled) 'Who BF unknown-word refusal is friendly and leaves input usable'
 AssertWhoGui (Test-Path -LiteralPath "$($response.RequestDirectory)/engine/host-error.json") 'failed Who request is preserved'
 ClickWhoGui $script:GuiControls.ClearButton
 AssertWhoGui ($script:GuiControls.HistoryPanel.Children.Count -eq 1 -and (Test-Path -LiteralPath "$($script:GuiState.SessionDirectory)/history.jsonl")) 'clear keeps saved Who runs'
 foreach($binding in $sourceRows){AssertWhoGui ((Get-FileHash -LiteralPath "$PSScriptRoot/$($binding.Path)").Hash -ceq $binding.SHA256) ('GUI source unchanged: '+$binding.Path)}
}catch{$testFailure=$_;$_|Out-String|Set-Content -LiteralPath "$testDirectory/failure.log" -Encoding UTF8}
finally{
 if($null -ne $script:GuiState -and $null -ne $script:GuiState.Worker){StopGuiGeneration}
 if($null -ne $script:GuiTimer){$script:GuiTimer.Stop()}
 if($null -ne $script:GuiWindow -and $script:GuiWindow.IsVisible){$script:GuiWindow.Close()}
 [IO.File]::WriteAllText("$testDirectory/report.json",(ConvertTo-Json @{Status=$(if($null -eq $testFailure){'PASS'}else{'FAIL'});Checks=$testChecks.ToArray();SessionDirectory=$script:GuiState.SessionDirectory} -Depth 5),[Text.UTF8Encoding]::new($false))
 Write-Output ('Report: '+$testDirectory)
}
if($null -ne $testFailure){throw $testFailure}
