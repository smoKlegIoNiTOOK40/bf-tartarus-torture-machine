param()
# Host metadata/byte-preservation tests only. No BF/model execution.
$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runDirectory=Join-Path $projectRoot ('tests/io-audit-v2/run-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
$utf8=[Text.UTF8Encoding]::new($false)
[void][IO.Directory]::CreateDirectory((Join-Path $runDirectory 'source'))
$sourceHashes=@{}
foreach ($sourceFile in Get-ChildItem -LiteralPath $PSScriptRoot -File) {
 Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $runDirectory ('source/'+$sourceFile.Name))
 $sourceHashes[$sourceFile.Name]=(Get-FileHash -LiteralPath $sourceFile.FullName).Hash
}
$checks=[Collections.Generic.List[object]]::new()
$status='FAIL';$clock=[Diagnostics.Stopwatch]::StartNew()
function Good([string]$name,[scriptblock]$body) {
 $null=& $body
 $checks.Add(@{Name=$name;Status='PASS';Expected='accept'})
}
function Bad([string]$name,[string]$message,[scriptblock]$body) {
 $failure=$null
 try { $null=& $body } catch { $failure=$_.Exception.Message }
 if (-not $failure -or -not $failure.Contains($message)) { throw ('Wrong rejection '+$name+': '+$failure) }
 $checks.Add(@{Name=$name;Status='PASS';Expected='reject';Reason=$failure})
}
function Assert([bool]$condition,[string]$name) { if (-not $condition) { throw ('Assertion: '+$name) } }
function JsonFile([string]$path,$value) { [IO.File]::WriteAllText($path,(ConvertTo-Json -InputObject $value -Depth 15 -Compress),$utf8) }
function WriteManifest([string]$text,$count) {
 [IO.File]::WriteAllText($manifest,$text,$utf8)
 JsonFile $seal @{Bindings=$count;SHA256=(Get-FileHash -LiteralPath $manifest).Hash}
}
function Verify { & $invoke -Operation VerifyManifest -RootDirectory $fixture -ManifestPath manifest.json -SealPath seal.json -ProgressEvery 0 -ProgressSeconds 0 -PassThru }
function Raw { & $invoke -Operation AuditRaw -RootDirectory $fixture -DataDirectory raw -Inventories origins.json -ProgressEvery 0 -ProgressSeconds 0 -PassThru }
function AuditJournal([string]$path) { & $invoke -Operation AuditJournal -RootDirectory $runDirectory -DataDirectory $path -ProgressEvery 0 -ProgressSeconds 0 -PassThru }
function CloneJournal([string]$name,[string]$skip='') {
 $path=Join-Path $runDirectory $name;[void][IO.Directory]::CreateDirectory($path)
 foreach ($file in Get-ChildItem -LiteralPath $journalPath -File) { if ($file.Name -cne $skip) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $path $file.Name) } }
 return $path
}
function JournalSeal([string]$path) { return (Get-Content -LiteralPath (Join-Path $path journal-seal.json) -Raw | ConvertFrom-Json) }
function SaveJournalSeal([string]$path,$value) { JsonFile (Join-Path $path journal-seal.json) $value }
function ChangeIndex([string]$path,[scriptblock]$change) {
 $value=JournalSeal $path;$block=$value.Blocks[0];$indexPath=Join-Path $path $block.IndexFile
 $lines=@(Get-Content -LiteralPath $indexPath);$row=$lines[0] | ConvertFrom-Json
 $null=& $change $row;$lines[0]=ConvertTo-Json -InputObject $row -Compress
 [IO.File]::WriteAllText($indexPath,($lines -join "`n")+"`n",$utf8)
 $block.IndexSHA256=(Get-FileHash -LiteralPath $indexPath).Hash;SaveJournalSeal $path $value
}
try {
 . (Join-Path $PSScriptRoot 'RawJournal.ps1')
 $invoke=Join-Path $PSScriptRoot Invoke-IOAudit.ps1
 $fixture=Join-Path $runDirectory fixtures;[void][IO.Directory]::CreateDirectory($fixture)
 $manifest=Join-Path $fixture manifest.json;$seal=Join-Path $fixture seal.json
 [IO.File]::WriteAllBytes((Join-Path $fixture abc.bin),[Text.Encoding]::ASCII.GetBytes('abc'))
 [IO.File]::WriteAllBytes((Join-Path $fixture empty.bin),[byte[]]@())
 $abcHash='BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'
 $emptyHash='E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
 $abcRow='{"Path":"abc.bin","SHA256":"'+$abcHash+'"}'
 $valid='['+$abcRow+']'
 Good 'literal SHA256 vectors' { Assert (([Tartarus.IOAuditV2.Files]::Hash((Join-Path $fixture abc.bin))) -ceq $abcHash) abc; Assert (([Tartarus.IOAuditV2.Files]::Hash((Join-Path $fixture empty.bin))) -ceq $emptyHash) empty }
 Good 'singleton manifest' { WriteManifest $valid 1;$result=Verify;Assert ($result.Bindings -eq 1 -and $result.Status -ceq 'PASS') singleton }
 Good 'empty manifest' { WriteManifest '[]' 0;$result=Verify;Assert ($result.Bindings -eq 0) empty }
 Good 'JSON unicode and escaped strings' {
  $parsed=[Tartarus.IOAuditV2.MetadataJson]::Parse('{"x":"\u0436\ud83d\ude42\n\"\\","n":42}')
  Assert ([Tartarus.IOAuditV2.MetadataJson]::Text($parsed,'x').StartsWith(([char]0x0436).ToString())) unicode
  $encoded=[Tartarus.IOAuditV2.MetadataJson]::Encode($parsed);$again=[Tartarus.IOAuditV2.MetadataJson]::Parse($encoded)
  Assert ([Tartarus.IOAuditV2.MetadataJson]::Text($again,'x') -ceq [Tartarus.IOAuditV2.MetadataJson]::Text($parsed,'x')) roundtrip
 }
 Good 'metadata strings agree with PowerShell JSON parser' {
  $random=[Random]::new(410)
  for ($sample=0;$sample -lt 32;$sample++) {
   $text=[Text.StringBuilder]::new();for($n=0;$n -lt 100;$n++){[void]$text.Append([char]$random.Next(0,256))}
   $wire=ConvertTo-Json -InputObject @{Text=$text.ToString()} -Compress
   $native=$wire|ConvertFrom-Json;$parsed=[Tartarus.IOAuditV2.MetadataJson]::Parse($wire)
   Assert ([Tartarus.IOAuditV2.MetadataJson]::Text($parsed,'Text') -ceq $native.Text) parserAgreement
  }
 }
 Good 'drive root path normalization' {
  $drive=[IO.Path]::GetPathRoot($projectRoot)
  Assert ([Tartarus.IOAuditV2.Files]::Within($drive.TrimEnd([IO.Path]::DirectorySeparatorChar),'example') -ceq ($drive+'example')) driveRoot
 }
 Good 'timer heartbeat during an otherwise silent phase' {
  $original=[Console]::Out;$capture=[IO.StringWriter]::new();$phase=$null
  try {
   [Console]::SetOut($capture);$timing=[Tartarus.IOAuditV2.AuditReport]::new()
   $phase=[Tartarus.IOAuditV2.ProgressPhase]::new($timing,'heartbeat',0,0,1)
   Start-Sleep -Milliseconds 1400;$phase.Finish(0);$phase.Dispose();$phase=$null
  } finally {if($phase){$phase.Dispose()};[Console]::SetOut($original)}
  Assert ($capture.ToString().Contains('IO WORK heartbeat')) heartbeat
 }
 foreach ($jsonFault in @('{"x":1,"x":2}','[1,]','01','true false','"\ud800"','{"x":}')) {
  Bad ('malformed JSON '+$jsonFault) 'Metadata JSON' { [Tartarus.IOAuditV2.MetadataJson]::Parse($jsonFault) }
 }
 foreach ($count in @(-1,1.5,$true,'1')) { WriteManifest $valid $count;Bad ('invalid seal count '+$count) 'Metadata nonnegative integer' { Verify } }
 WriteManifest $valid 2;Bad 'manifest count mismatch' 'manifest count mismatch' { Verify }
 WriteManifest $valid 1;[IO.File]::AppendAllText($manifest,' ',$utf8);Bad 'manifest seal mismatch' 'manifest seal mismatch' { Verify }
 WriteManifest ('['+$abcRow+','+$abcRow+']') 2;Bad 'duplicate artifact path' 'duplicate path' { Verify }
 WriteManifest ('['+$abcRow+',{ "Path":"./ABC.bin","SHA256":"'+$abcHash+'"}]') 2;Bad 'normalized case duplicate' 'duplicate path' { Verify }
 foreach ($path in @('../outside.bin','', ' ')) { $row=ConvertTo-Json -InputObject @{Path=$path;SHA256=$abcHash} -Compress;WriteManifest ('['+$row+']') 1;Bad ('bad artifact path '+$path) 'Audit path' { Verify } }
 WriteManifest '[{"Path":42,"SHA256":"bad"}]' 1;Bad 'non-string path' 'Metadata string' { Verify }
 WriteManifest '[{"Path":"abc.bin","SHA256":"bad"}]' 1;Bad 'malformed row hash' 'SHA256 shape' { Verify }
 WriteManifest ('[{"Path":"missing.bin","SHA256":"'+$abcHash+'"}]') 1;Bad 'missing artifact' 'file unavailable' { Verify }
 [void][IO.Directory]::CreateDirectory((Join-Path $fixture directory))
 WriteManifest ('[{"Path":"directory","SHA256":"'+$abcHash+'"}]') 1;Bad 'directory is not file' 'file unavailable' { Verify }
 WriteManifest ('[{"Path":"abc.bin","SHA256":"'+('0'*64)+'"}]') 1;Bad 'changed artifact hash' 'SHA256 mismatch' { Verify }
 WriteManifest $valid 1
 Good 'progress and phase timings preserve structured result' {
  $result=& $invoke -Operation VerifyManifest -RootDirectory $fixture -ManifestPath manifest.json -SealPath seal.json -ProgressEvery 1 -ProgressSeconds 1 -PassThru
  Assert ($result.Count -eq 1 -and $result.Phases.Count -eq 3) phases
  foreach ($phase in $result.Phases) { Assert ($phase.Complete -and $phase.Completed -eq $phase.Total) phaseComplete }
 }
 Good 'failure report contains FAIL' {
  $report=Join-Path $runDirectory expected-failure.json
  Bad 'failure report invocation' 'manifest count mismatch' { WriteManifest $valid 2;& $invoke -Operation VerifyManifest -RootDirectory $fixture -ManifestPath manifest.json -SealPath seal.json -ProgressEvery 0 -ProgressSeconds 0 -ReportPath $report }
  $value=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json;Assert ($value.Status -ceq 'FAIL' -and $value.Request.Operation -ceq 'VerifyManifest' -and $value.Request.ManifestPath -ceq 'manifest.json' -and $value.WrapperSHA256.Length -eq 64) failReport
 }
 $artifactDir=Join-Path $fixture artifacts;[void][IO.Directory]::CreateDirectory((Join-Path $artifactDir nested))
 [IO.File]::WriteAllBytes((Join-Path $artifactDir abc.bin),[Text.Encoding]::ASCII.GetBytes('abc'))
 [IO.File]::WriteAllBytes((Join-Path $artifactDir empty.bin),[byte[]]@())
 [IO.File]::WriteAllBytes((Join-Path $artifactDir ('nested/'+[char]0x0436+'.bin')),[byte[]]@(0,26,128,255))
 $built=Join-Path $fixture built;[void][IO.Directory]::CreateDirectory($built)
 Good 'build and independently verify manifest' {
  $result=& $invoke -Operation BuildManifest -RootDirectory $fixture -DataDirectory artifacts -ManifestPath built/hashes.json -SealPath built/seal.json -ProgressEvery 0 -ProgressSeconds 0 -PassThru
  Assert ($result.Bindings -eq 3) builtCount
  $rows=Get-Content -LiteralPath (Join-Path $built hashes.json) -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($row in $rows) { Assert ((Get-FileHash -LiteralPath (Join-Path $fixture $row.Path)).Hash -ceq $row.SHA256) independentHash }
  $checked=& $invoke -Operation VerifyManifest -RootDirectory $fixture -ManifestPath built/hashes.json -SealPath built/seal.json -ProgressEvery 0 -ProgressSeconds 0 -PassThru
  Assert ($checked.Bindings -eq 3) independentPass
 }
 Bad 'manifest builder refuses overwrite' 'output already exists' { & $invoke -Operation BuildManifest -RootDirectory $fixture -DataDirectory artifacts -ManifestPath built/hashes.json -SealPath built/seal.json -ProgressEvery 0 -ProgressSeconds 0 }
 Good 'deterministic manifest order' {
  $null=& $invoke -Operation BuildManifest -RootDirectory $fixture -DataDirectory artifacts -ManifestPath built/hashes2.json -SealPath built/seal2.json -ProgressEvery 0 -ProgressSeconds 0 -PassThru
  Assert ((Get-FileHash -LiteralPath (Join-Path $built hashes.json)).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $built hashes2.json)).Hash) deterministic
  Assert ([Tartarus.IOAuditV2.Files]::CompareManifests($fixture,(Join-Path $built hashes.json),(Join-Path $built hashes2.json)) -eq 3) manifestMap
 }
 $rawDir=Join-Path $fixture raw;[void][IO.Directory]::CreateDirectory($rawDir)
 [IO.File]::WriteAllBytes((Join-Path $rawDir request.in),[Text.Encoding]::ASCII.GetBytes('abc'))
 [IO.File]::WriteAllBytes((Join-Path $rawDir request.out),[byte[]]@())
 [IO.File]::WriteAllText((Join-Path $rawDir request.json),'{}',$utf8)
 $rawRow=@{Source='fixture.bf';Phase='fixtures';Kind='fresh';InputPath=(Join-Path $rawDir request.in);OutputPath=(Join-Path $rawDir request.out);MetadataPath=(Join-Path $rawDir request.json);InputSHA256=$abcHash;OutputSHA256=$emptyHash}
 $origins=Join-Path $rawDir origins.json;JsonFile $origins @($rawRow)
 Good 'legacy raw integrity counts' { $result=Raw;Assert ($result.Origins -eq 1 -and $result.UniqueRawFiles -eq 3 -and $result.Kinds.fresh -eq 1) rawCounts }
 JsonFile $origins @($rawRow,$rawRow);Bad 'raw duplicate paths' 'raw duplicate path' { Raw }
 $badRow=$rawRow.Clone();$badRow.InputSHA256='0'*64;JsonFile $origins @($badRow);Bad 'raw changed input' 'SHA256 mismatch' { Raw }
 $badRow=$rawRow.Clone();$badRow.OutputSHA256='0'*64;JsonFile $origins @($badRow);Bad 'raw changed output' 'SHA256 mismatch' { Raw }
 $badRow=$rawRow.Clone();$badRow.MetadataPath=Join-Path $rawDir missing.json;JsonFile $origins @($badRow);Bad 'raw missing metadata' 'file unavailable' { Raw }
 $badRow=$rawRow.Clone();$badRow.InputPath=Join-Path $fixture abc.bin;JsonFile $origins @($badRow);Bad 'raw path escape' 'path outside root' { Raw }
 JsonFile $origins @($rawRow)
 $journalPath=Join-Path $runDirectory journal
 $records=@(
  @{Input=[byte[]]@();Output=[byte[]]@()},
  @{Input=[byte[]](0..255);Output=[byte[]](255..0)},
  @{Input=[byte[]]@(26,0,255);Output=[byte[]]@(128)},
  @{Input=[byte[]]@();Output=[byte[]]@(13,10)},
  @{Input=[byte[]]@(1);Output=[byte[]]@()}
 )
 Good 'block journal writer and rotation' {
  $writer=New-TartarusRawJournal -Directory $journalPath -BlockBytes 200 -BlockOrigins 2
  try {
   for ($i=0;$i -lt $records.Count;$i++) { $id=Add-TartarusRawOrigin -Journal $writer -Source ('source"'+[char]0x0436+'.bf') -Phase "test`nphase" -Kind fresh -InputBytes $records[$i].Input -OutputBytes $records[$i].Output;Assert ($id -eq $i) originId }
   $summary=$writer.Complete();Assert ($summary.Origins -eq 5 -and $summary.Blocks -ge 3) rotation
   Bad 'append after seal' 'closed or failed' { $writer.Append('s','p','k',[byte[]]@(),[byte[]]@()) }
   Bad 'seal twice' 'closed or failed' { $writer.Complete() }
  } finally { $writer.Dispose() }
 }
 Good 'block journal full audit' { $result=AuditJournal $journalPath;Assert ($result.Origins -eq 5 -and $result.Kinds.fresh -eq 5) journalAudit }
 Good 'all 256 bytes and empty payloads roundtrip' {
  for ($i=0;$i -lt $records.Count;$i++) { $restored=[Tartarus.IOAuditV2.Journals]::ReadOrigin($journalPath,$i);Assert ([Tartarus.IOAuditV2.Files]::Same($restored.Input,$records[$i].Input)) inputBytes;Assert ([Tartarus.IOAuditV2.Files]::Same($restored.Output,$records[$i].Output)) outputBytes;Assert ($restored.Phase -ceq "test`nphase") metadata }
 }
 Bad 'journal writer refuses existing directory' 'already exists' { New-TartarusRawJournal -Directory $journalPath }
 Bad 'journal nonexistent record' 'id' { [Tartarus.IOAuditV2.Journals]::ReadOrigin($journalPath,99) }
 Good 'sealed empty journal' { $writer=New-TartarusRawJournal -Directory (Join-Path $runDirectory empty-journal);try {$summary=$writer.Complete()}finally{$writer.Dispose()};$result=AuditJournal $summary.Directory;Assert ($result.Origins -eq 0 -and $result.Bindings -eq 1) emptyJournal }
 $incomplete=Join-Path $runDirectory incomplete-journal;$writer=New-TartarusRawJournal -Directory $incomplete;$null=$writer.Append('s','p','k',[byte[]]@(26),[byte[]]@(255));$writer.Dispose()
 Bad 'incomplete journal never passes' 'journal-seal.json' { AuditJournal $incomplete }
 $clone=CloneJournal corrupt-block;$value=JournalSeal $clone;$block=@($value.Blocks | Where-Object {$_.DataLength -gt 0})[0];$path=Join-Path $clone $block.DataFile;$bytes=[IO.File]::ReadAllBytes($path);$bytes[0]=$bytes[0] -bxor 1;[IO.File]::WriteAllBytes($path,$bytes)
 Bad 'corrupt data block' 'file hash mismatch' { AuditJournal $clone }
 $clone=CloneJournal corrupt-index;[IO.File]::AppendAllText((Join-Path $clone 'block-000000.jsonl'),' ',$utf8)
 Bad 'corrupt index' 'file hash mismatch' { AuditJournal $clone }
 $clone=CloneJournal missing-block block-000000.bin;Bad 'missing journal block' 'file unavailable' { AuditJournal $clone }
 $clone=CloneJournal wrong-offset;ChangeIndex $clone {param($row) $row.InputOffset=1};Bad 'index offset mismatch' 'input offset' { AuditJournal $clone }
 $clone=CloneJournal wrong-origin-hash;ChangeIndex $clone {param($row) $row.InputSHA256='0'*64};Bad 'origin hash after index reseal' 'origin hash mismatch' { AuditJournal $clone }
 $clone=CloneJournal wrong-id;ChangeIndex $clone {param($row) $row.Id=1};Bad 'origin id order' 'origin id order' { AuditJournal $clone }
 $clone=CloneJournal wrong-count;$value=JournalSeal $clone;$value.Origins++;SaveJournalSeal $clone $value;Bad 'journal total count mismatch' 'total count' { AuditJournal $clone }
 $clone=CloneJournal open-seal;$value=JournalSeal $clone;$value.Closed=$false;SaveJournalSeal $clone $value;Bad 'unclosed seal' 'incomplete or format' { AuditJournal $clone }
 $clone=CloneJournal duplicate-block;$value=JournalSeal $clone;$value.Blocks=@($value.Blocks)+@($value.Blocks[0]);SaveJournalSeal $clone $value;Bad 'duplicate journal paths' 'duplicate path' { AuditJournal $clone }
 $clone=CloneJournal outside-block;$value=JournalSeal $clone;$value.Blocks[0].DataFile='../outside.bin';SaveJournalSeal $clone $value;Bad 'journal path escape' 'path outside root' { AuditJournal $clone }
 $clone=CloneJournal extra-file;[IO.File]::WriteAllText((Join-Path $clone extra.txt),'x',$utf8);Bad 'untracked journal file' 'untracked file' { AuditJournal $clone }
 $clone=CloneJournal extra-directory;[void][IO.Directory]::CreateDirectory((Join-Path $clone extra));Bad 'untracked journal directory' 'nonregular entry' { AuditJournal $clone }
 $clone=CloneJournal extra-data;$value=JournalSeal $clone;$block=$value.Blocks[0];$path=Join-Path $clone $block.DataFile;[IO.File]::WriteAllBytes($path,[byte[]]@(42));$block.DataLength=1;$block.DataSHA256=(Get-FileHash -LiteralPath $path).Hash;SaveJournalSeal $clone $value
 Bad 'unindexed bytes after block reseal' 'coverage/count' { AuditJournal $clone }
 Good 'legacy bytes copied into new journal' {
  $packed=Join-Path $runDirectory packed-legacy;$summary=[Tartarus.IOAuditV2.Journals]::PackLegacy($rawDir,[string[]]@('origins.json'),$packed,67108864,10000)
  $result=AuditJournal $packed;Assert ($result.Origins -eq 1) packedCount
  $record=[Tartarus.IOAuditV2.Journals]::ReadOrigin($packed,0);Assert ([Text.Encoding]::ASCII.GetString($record.Input) -ceq 'abc') packedInput;Assert ($record.Output.Length -eq 0) packedOutput
 }
 $pipelineData=Join-Path $runDirectory pipeline-data
 Good 'complete host archive pipeline with block journal' {
  [void][IO.Directory]::CreateDirectory($pipelineData)
  [IO.File]::WriteAllBytes((Join-Path $pipelineData payload.bin),[byte[]]@(0,26,128,255))
  $writer=New-TartarusRawJournal -Directory (Join-Path $pipelineData raw)
  try {$null=$writer.Append('s','p','fresh',[byte[]](0..255),[byte[]]@());$null=$writer.Complete()}finally{$writer.Dispose()}
  $pipelineReport=Join-Path $runDirectory pipeline-report.json
  $pipeline=& (Join-Path $PSScriptRoot Complete-IOArchive.ps1) -RootDirectory $runDirectory -DataDirectory $pipelineData -Mode BlockJournal -Journals raw -ReportPath $pipelineReport -ProgressEvery 0 -ProgressSeconds 0 -PassThru
  Assert ($pipeline.Status -ceq 'PASS' -and $pipeline.Guard.Bindings -eq 5) pipeline
  $pipelineRows=Get-Content -LiteralPath (Join-Path $pipelineData artifact-hashes.json) -Raw|ConvertFrom-Json
  foreach($row in $pipelineRows){Assert ((Get-FileHash -LiteralPath (Join-Path $runDirectory $row.Path)).Hash -ceq $row.SHA256) pipelineHash}
 }
 Bad 'completed archive refuses overwrite' 'output already exists' {
  & (Join-Path $PSScriptRoot Complete-IOArchive.ps1) -RootDirectory $runDirectory -DataDirectory $pipelineData -Mode BlockJournal -Journals raw -ReportPath (Join-Path $runDirectory duplicate-report.json) -ProgressEvery 0 -ProgressSeconds 0
 }
 Good 'failed journal cannot publish an archive manifest' {
  $failedData=Join-Path $runDirectory failed-pipeline;[void][IO.Directory]::CreateDirectory($failedData)
  $writer=New-TartarusRawJournal -Directory (Join-Path $failedData raw);$writer.Dispose()
  $failedReport=Join-Path $runDirectory failed-pipeline-report.json
  Bad 'pipeline rejects unsealed journal' 'journal-seal.json' { & (Join-Path $PSScriptRoot Complete-IOArchive.ps1) -RootDirectory $runDirectory -DataDirectory $failedData -Mode BlockJournal -Journals raw -ReportPath $failedReport -ProgressEvery 0 -ProgressSeconds 0 }
  Assert (-not(Test-Path -LiteralPath (Join-Path $failedData artifact-hashes.json))) noManifest
  $failed=Get-Content -LiteralPath $failedReport -Raw|ConvertFrom-Json;Assert ($failed.Status -ceq 'FAIL') failedPipeline
 }
 $status='PASS'
} finally {
 $clock.Stop();$proof=[ordered]@{Status=$status;Checks=$checks.ToArray();TotalChecks=$checks.Count;Sources=$sourceHashes;PowerShell=$PSVersionTable.PSVersion.ToString();ElapsedMilliseconds=$clock.ElapsedMilliseconds;ModelArithmetic=$false;BFExecutions=0;FrozenStagesChanged=$false}
 [IO.File]::WriteAllText((Join-Path $runDirectory suite.json),(ConvertTo-Json -InputObject $proof -Depth 12),$utf8)
 Write-Host ('{0} {1} metadata checks; {2}' -f $status,$checks.Count,(Join-Path $runDirectory suite.json))
}
