# Host transport only. The same ordinary qdb executes every BF instruction.
# Drain stdout and stderr before async stdin writing, with one 30s total budget.
function LaunchRaw74($source,[byte[]]$inputBytes){
 if($null -eq $inputBytes){$inputBytes=[byte[]]@()}
 $startInfo=[Diagnostics.ProcessStartInfo]::new();$startInfo.FileName=Join-Path $root 'tools/qdb/qdb.exe';$startInfo.Arguments='"'+$source+'"';$startInfo.WorkingDirectory=$root
 $startInfo.UseShellExecute=$false;$startInfo.CreateNoWindow=$true;$startInfo.RedirectStandardInput=$true;$startInfo.RedirectStandardOutput=$true;$startInfo.RedirectStandardError=$true
 $process=[Diagnostics.Process]::new();$process.StartInfo=$startInfo;$output=[IO.MemoryStream]::new();$started=$false;$read=$null;$readError=$null;$clock=[Diagnostics.Stopwatch]::new();$errorText=''
 try{
  [void]$process.Start();$started=$true;$clock.Start()
  $read=$process.StandardOutput.BaseStream.CopyToAsync($output);$readError=$process.StandardError.ReadToEndAsync()
  $write=$process.StandardInput.BaseStream.WriteAsync($inputBytes,0,$inputBytes.Length)
  if(-not $write.Wait(30000)){throw 'BF input timeout'};[void]$write.GetAwaiter().GetResult();$process.StandardInput.Close()
  $remaining=[int][Math]::Max(1,30000-$clock.ElapsedMilliseconds)
  if(-not $process.WaitForExit($remaining)){throw 'BF execution timeout'}
  [void]$read.GetAwaiter().GetResult();$errorText=$readError.GetAwaiter().GetResult()
  if($process.ExitCode -ne 0){throw ('BF interpreter exit '+$process.ExitCode)}
  return ,$output.ToArray()
 }catch{
  $message=$_.Exception.Message
  if($started){try{if(-not $process.HasExited){$process.Kill()}}catch{};try{$process.StandardInput.Close()}catch{};if($null -ne $read){try{[void]$read.GetAwaiter().GetResult()}catch{}};if($null -ne $readError){try{$errorText=$readError.GetAwaiter().GetResult()}catch{}}}
  $failure=[Exception]::new(('BF physical failure: '+$message+': '+$source));$failure.Data['TartarusStarted74']=$started;$failure.Data['TartarusRaw74']=$output.ToArray();$failure.Data['TartarusStderr74']=$errorText
  throw $failure
 }finally{$clock.Stop();$process.Dispose();$output.Dispose()}
}
