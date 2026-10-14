param()
$ErrorActionPreference='Stop'
$testDirectory=Join-Path $PSScriptRoot ('checks/copy8-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDirectory)
$testChecks=[Collections.Generic.List[string]]::new();$testFailure=$null
function AssertCopyGui([bool]$condition,[string]$name){if(-not $condition){throw ('FAIL: '+$name)};$testChecks.Add($name);Write-Output ('PASS: '+$name)}
function PumpCopyGui([int]$milliseconds=50){
 $frame=[Windows.Threading.DispatcherFrame]::new();$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds($milliseconds)
 $stop={ $frame.Continue=$false;$timer.Stop() }.GetNewClosure();$timer.Add_Tick($stop);$timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
}
function ClickCopyGui($button){$button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))}
function WaitCopyGui {
 $deadline=[DateTime]::UtcNow.AddMinutes(4)
 while($null -ne $script:GuiState.Worker){if([DateTime]::UtcNow -gt $deadline){throw 'Copy8 GUI worker timeout'};PumpCopyGui 100}
 return $script:GuiState.LastResult
}
function SaveCopyGuiImage([string]$name){
 $script:GuiWindow.UpdateLayout();$visual=$script:GuiWindow.Content
 $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$visual.ActualWidth,[int]$visual.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
 $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create((Join-Path $testDirectory $name));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
function CheckCopyGuiAnswer($response,[string]$expected,[bool]$withHistory){
 AssertCopyGui ($response.Status -ceq 'ok' -and $response.Stop -ceq 'eos' -and $response.Continuation -ceq (' '+$expected)) ('actual BF answer: '+$response.Prompt+' -> '+$expected)
 AssertCopyGui ($response.HistoryUsed -eq $withHistory -and $script:GuiState.MemoryPath -ceq $response.HistoryContextPath) 'only a successful actual answer advances memory'
 AssertCopyGui ($response.Text -ceq ($response.Prompt+[Environment]::NewLine+$expected)) 'copied question and answer occupy separate lines'
 $engine=$response.EngineDirectory
 $status=Get-Content -LiteralPath "$engine/run-status.json" -Raw|ConvertFrom-Json
 $proof=Get-Content -LiteralPath ($engine+'-host.json') -Raw|ConvertFrom-Json
 $revision=Get-Content -LiteralPath "$engine/source-revision.json" -Raw|ConvertFrom-Json
 AssertCopyGui ($status.NumericalStatus -ceq 'PASS' -and $status.SourceStatus -ceq 'PASS' -and $proof.Status -ceq 'PASS') 'answer retains numerical, source and full raw/artifact proof'
 AssertCopyGui ($revision.Format -ceq 'shared-snapshot-v1' -and -not $revision.PerRequestSourceCopy -and -not (Test-Path -LiteralPath "$engine/source")) 'answer reuses the sealed source snapshot'
 AssertCopyGui ((Get-ChildItem -LiteralPath $response.RequestDirectory -Recurse -File|Measure-Object Length -Sum).Sum -lt 1048576) 'request stays below one MiB'
 AssertCopyGui ($script:GuiControls.FollowupPanel.Visibility -eq [Windows.Visibility]::Visible -and $script:GuiControls.PromptBox.Text -ceq '') 'answer exposes followup controls and clears the composer'
}
# Small host sources are preserved before the first numerical worker.
$sourceDirectory=Join-Path $testDirectory 'gui-source';[void][IO.Directory]::CreateDirectory($sourceDirectory)
$sourceRows=@(foreach($file in @('app.ps1','worker.ps1','window.xaml','OwnedWorker.cs','test-copy8.ps1')){
 Copy-Item -LiteralPath "$PSScriptRoot/$file" -Destination "$sourceDirectory/$file"
 @{Path=$file;SHA256=(Get-FileHash -LiteralPath "$sourceDirectory/$file").Hash}
})
[IO.File]::WriteAllText("$sourceDirectory/files.json",(ConvertTo-Json $sourceRows -Depth 4),[Text.UTF8Encoding]::new($false))
try{
 . "$PSScriptRoot/app.ps1" -NoShow
 $script:GuiWindow.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual;$script:GuiWindow.Left=-12000;$script:GuiWindow.Top=0;$script:GuiWindow.Show();PumpCopyGui 100
 AssertCopyGui ($script:GuiControls.ArmBox.SelectedIndex -eq 3 -and $script:GuiControls.ModelTitle.Text -ceq 'Диалог') 'learned eight-word dialogue is the default model'
 AssertCopyGui ($script:GuiControls.VocabularyPanel.Children.Count -eq 30 -and $script:GuiControls.ExamplesPanel.Children.Count -eq 4) 'actual vocabulary and four fact examples are visible'
 AssertCopyGui ($null -eq $script:GuiState.MemoryPath -and $script:GuiControls.FollowupPanel.Visibility -eq [Windows.Visibility]::Collapsed) 'new dialogue starts without fabricated history'
 SaveCopyGuiImage 'welcome.png'
 ClickCopyGui $script:GuiControls.SendButton
 $worker=$script:GuiState.Worker
 AssertCopyGui ($null -ne $worker -and -not $script:GuiControls.ArmBox.IsEnabled -and -not $script:GuiControls.FollowupPanel.IsEnabled) 'owned background worker locks model and followup actions'
 ClickCopyGui $script:GuiControls.SendButton
 AssertCopyGui ([object]::ReferenceEquals($worker,$script:GuiState.Worker)) 'double submission cannot create another worker'
 $first=WaitCopyGui;CheckCopyGuiAnswer $first 'mira' $false
 ClickCopyGui $script:GuiControls.AskWhatButton
 AssertCopyGui ($script:GuiControls.PromptBox.Text -ceq 'what' -and $null -eq $script:GuiState.Worker) 'followup chip fills input without submitting'
 ClickCopyGui $script:GuiControls.SendButton;$second=WaitCopyGui;CheckCopyGuiAnswer $second 'a red key' $true
 $origin=Get-Content -LiteralPath "$($second.EngineDirectory)/history-input-origin.json" -Raw|ConvertFrom-Json
 AssertCopyGui ($origin.Path -ceq $first.HistoryContextPath -and $origin.SHA256 -ceq (Get-FileHash -LiteralPath $first.HistoryContextPath).Hash -and $origin.ActualPriorArtifactVerified -and -not $origin.GoldHistoryUsed) 'second turn binds the first actual answer rather than a gold name'
 SaveCopyGuiImage 'linked-answers.png'
 ClickCopyGui $script:GuiControls.ExamplesPanel.Children[3]
 AssertCopyGui ($null -eq $script:GuiState.MemoryPath) 'choosing another fact starts with empty model memory'
 ClickCopyGui $script:GuiControls.SendButton;$placeFirst=WaitCopyGui;CheckCopyGuiAnswer $placeFirst 'oren' $false
 ClickCopyGui $script:GuiControls.AskWhereButton;ClickCopyGui $script:GuiControls.SendButton;$placeSecond=WaitCopyGui;CheckCopyGuiAnswer $placeSecond 'near the bench' $true
 ClickCopyGui $script:GuiControls.ExamplesPanel.Children[1];ClickCopyGui $script:GuiControls.SendButton;$object=WaitCopyGui;CheckCopyGuiAnswer $object 'the blue box' $false
 ClickCopyGui $script:GuiControls.ExamplesPanel.Children[2];ClickCopyGui $script:GuiControls.SendButton;$place=WaitCopyGui;CheckCopyGuiAnswer $place 'under the green lamp' $false
 $memoryBefore=$script:GuiState.MemoryPath
 $script:GuiControls.PromptBox.Text='purple';ClickCopyGui $script:GuiControls.SendButton;$unknown=WaitCopyGui
 AssertCopyGui ($unknown.Status -ceq 'error' -and $unknown.ErrorKind -ceq 'vocabulary' -and $script:GuiState.MemoryPath -ceq $memoryBefore) 'unknown-word failure preserves the last valid memory'
 AssertCopyGui (Test-Path -LiteralPath "$($unknown.RequestDirectory)/engine/host-error.json") 'failed numerical request remains inspectable'
 # Copy a closed successful run to a deliberately damaged fixture. Rebase only
 # archival paths; never alter an authentic run or model. Preserve the fixture
 # before damage, then require the runtime to reject its changed history byte.
 $archiveRoot=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
 $fixture=Join-Path $script:GuiState.SessionDirectory 'damaged-history-fixture'
 Copy-Item -LiteralPath $place.EngineDirectory -Destination $fixture -Recurse
 $oldPrefix=$place.EngineDirectory.Substring($archiveRoot.Length+1)+'\';$newPrefix=$fixture.Substring($archiveRoot.Length+1)+'\'
 $bindings=Get-Content -LiteralPath "$fixture/artifact-hashes.json" -Raw|ConvertFrom-Json
 foreach($binding in $bindings){if(-not $binding.Path.StartsWith($oldPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected fixture binding'};$binding.Path=$newPrefix+$binding.Path.Substring($oldPrefix.Length)}
 [IO.File]::WriteAllText("$fixture/artifact-hashes.json",(ConvertTo-Json -InputObject $bindings -Depth 5 -Compress),[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText("$fixture/artifact-seal.json",(ConvertTo-Json @{Bindings=$bindings.Count;SHA256=(Get-FileHash -LiteralPath "$fixture/artifact-hashes.json").Hash} -Compress),[Text.UTF8Encoding]::new($false))
 Copy-Item -LiteralPath $fixture -Destination "$testDirectory/history-fixture-before-damage" -Recurse
 [IO.File]::WriteAllBytes("$fixture/final-history.context",[Text.Encoding]::ASCII.GetBytes('AAAAAAAAAAAAAAAA'))
 $script:GuiState.MemoryPath="$fixture/final-history.context";$script:GuiControls.PromptBox.Text='where';ClickCopyGui $script:GuiControls.SendButton;$damaged=WaitCopyGui
 AssertCopyGui ($damaged.Status -ceq 'error' -and $damaged.ErrorKind -ceq 'history' -and $damaged.Message.Contains('Новая беседа')) 'altered history is refused with a usable recovery instruction'
 AssertCopyGui ($script:GuiState.MemoryPath -ceq "$fixture/final-history.context") 'history failure never commits a partial context'
 $script:GuiState.MemoryPath=$memoryBefore
 $held=Join-Path $testDirectory 'held';[void][IO.Directory]::CreateDirectory($held)
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSScriptRoot+'\fixtures\hold-worker.ps1" -Directory "'+$held+'"'
 $script:GuiState.Worker=[Tartarus.Gui.OwnedWorker]::new("$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe",$arguments,$PSScriptRoot)
 $script:GuiState.RequestDirectory=$held;$script:GuiState.Prompt='where';$script:GuiState.Arm='copy8';$script:GuiState.Deadline=[DateTime]::UtcNow.AddMinutes(2);SetGuiBusy $true
 $deadline=[DateTime]::UtcNow.AddSeconds(15)
 while(-not (Test-Path -LiteralPath "$held/child.pid")){if([DateTime]::UtcNow -gt $deadline -or $script:GuiState.Worker.Process.HasExited){throw 'Held child did not start'};PumpCopyGui}
 $childId=[int](Get-Content -LiteralPath "$held/child.pid" -Raw)
 AssertCopyGui (@($script:GuiState.Worker.GetProcessIds()) -contains $childId) 'cancellation fixture contains an ordinary BF child'
 ClickCopyGui $script:GuiControls.StopButton
 AssertCopyGui ($script:GuiState.LastResult.Status -ceq 'cancelled' -and $script:GuiState.MemoryPath -ceq $memoryBefore -and $null -eq $script:GuiState.Worker) 'cancellation preserves memory and releases the worker'
 AssertCopyGui ($null -eq (Get-Process -Id $childId -ErrorAction SilentlyContinue)) 'cancellation also terminates the BF child'
 $script:GuiWindow.Width=940;$script:GuiWindow.Height=690;PumpCopyGui 100
 $contentHost=$script:GuiControls.PromptBox.Template.FindName('PART_ContentHost',$script:GuiControls.PromptBox)
 AssertCopyGui ($contentHost.ViewportHeight -ge 20 -and $script:GuiControls.PromptBox.ActualWidth -gt 300 -and $script:GuiControls.AskWhereButton.ActualWidth -gt 30) 'composer and followup controls remain usable at minimum size'
 SaveCopyGuiImage 'minimum-size.png'
 $script:GuiControls.ArmBox.SelectedIndex=2;PumpCopyGui
 AssertCopyGui ($null -eq $script:GuiState.MemoryPath -and $script:GuiControls.FollowupPanel.Visibility -eq [Windows.Visibility]::Collapsed) 'changing models clears dialogue memory'
 $script:GuiControls.ArmBox.SelectedIndex=3;PumpCopyGui
 $script:GuiState.MemoryPath=$memoryBefore;ClickCopyGui $script:GuiControls.ClearButton
 AssertCopyGui ($null -eq $script:GuiState.MemoryPath -and $script:GuiControls.HistoryPanel.Children.Count -eq 1 -and (Test-Path -LiteralPath $memoryBefore)) 'new dialogue clears window and memory while retaining saved runs'
 foreach($binding in $sourceRows){AssertCopyGui ((Get-FileHash -LiteralPath "$PSScriptRoot/$($binding.Path)").Hash -ceq $binding.SHA256) ('GUI source unchanged: '+$binding.Path)}
}catch{$testFailure=$_;$_|Out-String|Set-Content -LiteralPath "$testDirectory/failure.log" -Encoding UTF8}
finally{
 if($null -ne $script:GuiState -and $null -ne $script:GuiState.Worker){StopGuiGeneration}
 if($null -ne $script:GuiTimer){$script:GuiTimer.Stop()}
 if($null -ne $script:GuiWindow -and $script:GuiWindow.IsVisible){$script:GuiWindow.Close()}
 [IO.File]::WriteAllText("$testDirectory/report.json",(ConvertTo-Json @{Status=$(if($null -eq $testFailure){'PASS'}else{'FAIL'});Checks=$testChecks.ToArray();SessionDirectory=$script:GuiState.SessionDirectory} -Depth 5),[Text.UTF8Encoding]::new($false))
 Write-Output ('Report: '+$testDirectory)
}
if($null -ne $testFailure){throw $testFailure}
