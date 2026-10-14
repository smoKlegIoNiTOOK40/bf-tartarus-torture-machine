function BankCompact77([int]$rows,[switch]$Seed,[byte[]]$BiasedLabels){
 $bankCompact77=Bytes75 ('0'*(16*($rows+1)));$bankCompact77[16*$rows+12]=97
 for($rowCompact77=0;$rowCompact77 -lt $rows;$rowCompact77++){if($Seed){$bankCompact77[16*$rowCompact77+11]=49};if($null -ne $BiasedLabels){[Array]::Copy($BiasedLabels,$rowCompact77,$bankCompact77,16*$rowCompact77+8,1)}}
 return ,$bankCompact77
}
function GridsCompact77(){
 $quadGridSource77=[IO.File]::ReadAllBytes("$root/tests/freqquad32-preflight03-v1/grid.records");if($quadGridSource77.Length -ne 20480){throw 'Compact frozen quad grid framing'}
 $quadGrid77=[byte[]]::new(16384);for($ordinalGridCompact77=0;$ordinalGridCompact77 -lt 4096;$ordinalGridCompact77++){[Array]::Copy($quadGridSource77,5*$ordinalGridCompact77,$quadGrid77,4*$ordinalGridCompact77,4)}
 $featureGridSource77=[IO.File]::ReadAllBytes("$root/tests/freqtable32-preflight04-v1/exhaustive.grid");if($featureGridSource77.Length -ne 450*84){throw 'Compact frozen feature grid framing'}
 $featureGrid77=[byte[]]::new(900);for($ordinalGridCompact77=0;$ordinalGridCompact77 -lt 450;$ordinalGridCompact77++){[Array]::Copy($featureGridSource77,84*$ordinalGridCompact77,$featureGrid77,2*$ordinalGridCompact77,2)}
 return @{quad=$quadGrid77;feature=$featureGrid77}
}
function BoundariesCompact77($name,[int]$rows){
 $seedBoundaryCompact77=BankCompact77 $rows -Seed;$loadedBoundaryCompact77=BankCompact77 $rows -BiasedLabels (Bytes75 ('1'*$rows));$statesBoundaryCompact77=[Collections.Generic.List[object]]::new()
 $statesBoundaryCompact77.Add(@{Name='seed';Tape=$seedBoundaryCompact77;Fields=0;Loaded=$false;Output=''})
 $statesBoundaryCompact77.Add(@{Name='load';Tape=$loadedBoundaryCompact77;Fields=0;Loaded=$true;Output=''})
 $aBoundaryCompact77=[byte[]]$loadedBoundaryCompact77.Clone();$aBoundaryCompact77[1]=49;$statesBoundaryCompact77.Add(@{Name='a';Tape=$aBoundaryCompact77;Fields=1;Loaded=$true;Output=''})
 $bBoundaryCompact77=[byte[]]$aBoundaryCompact77.Clone()
 if($name -ceq 'feature'){
  $bBoundaryCompact77[15*16+3]=49;$statesBoundaryCompact77.Add(@{Name='b';Tape=$bBoundaryCompact77;Fields=2;Loaded=$true;Output=''})
  $copyBoundaryCompact77=[byte[]]$bBoundaryCompact77.Clone();$copyBoundaryCompact77[16*16+9]=49;$statesBoundaryCompact77.Add(@{Name='copy';Tape=$copyBoundaryCompact77;Fields=2;Loaded=$true;Output=''})
  $returnBBoundaryCompact77=[byte[]]$aBoundaryCompact77.Clone();$returnBBoundaryCompact77[15*16+9]=49;$statesBoundaryCompact77.Add(@{Name='return-b';Tape=$returnBBoundaryCompact77;Fields=2;Loaded=$true;Output=''})
  $returnABoundaryCompact77=[byte[]]$loadedBoundaryCompact77.Clone();$returnABoundaryCompact77[9]=49;$statesBoundaryCompact77.Add(@{Name='return-a';Tape=$returnABoundaryCompact77;Fields=2;Loaded=$true;Output=''})
  $fieldsBoundaryCompact77=2
 }else{
  $bBoundaryCompact77[512*16+3]=49;$statesBoundaryCompact77.Add(@{Name='b';Tape=$bBoundaryCompact77;Fields=2;Loaded=$true;Output=''})
  $cBoundaryCompact77=[byte[]]$bBoundaryCompact77.Clone();$cBoundaryCompact77[576*16+5]=49;$statesBoundaryCompact77.Add(@{Name='c';Tape=$cBoundaryCompact77;Fields=3;Loaded=$true;Output=''})
  $dBoundaryCompact77=[byte[]]$cBoundaryCompact77.Clone();$dBoundaryCompact77[584*16+7]=49;$statesBoundaryCompact77.Add(@{Name='d';Tape=$dBoundaryCompact77;Fields=4;Loaded=$true;Output=''})
  $copyBoundaryCompact77=[byte[]]$dBoundaryCompact77.Clone();$copyBoundaryCompact77[585*16+9]=49;$statesBoundaryCompact77.Add(@{Name='copy';Tape=$copyBoundaryCompact77;Fields=4;Loaded=$true;Output=''})
  $returnDBoundaryCompact77=[byte[]]$cBoundaryCompact77.Clone();$returnDBoundaryCompact77[584*16+9]=49;$statesBoundaryCompact77.Add(@{Name='return-d';Tape=$returnDBoundaryCompact77;Fields=4;Loaded=$true;Output=''})
  $returnCBoundaryCompact77=[byte[]]$bBoundaryCompact77.Clone();$returnCBoundaryCompact77[576*16+9]=49;$statesBoundaryCompact77.Add(@{Name='return-c';Tape=$returnCBoundaryCompact77;Fields=4;Loaded=$true;Output=''})
  $returnBBoundaryCompact77=[byte[]]$aBoundaryCompact77.Clone();$returnBBoundaryCompact77[512*16+9]=49;$statesBoundaryCompact77.Add(@{Name='return-b';Tape=$returnBBoundaryCompact77;Fields=4;Loaded=$true;Output=''})
  $returnABoundaryCompact77=[byte[]]$loadedBoundaryCompact77.Clone();$returnABoundaryCompact77[9]=49;$statesBoundaryCompact77.Add(@{Name='return-a';Tape=$returnABoundaryCompact77;Fields=4;Loaded=$true;Output=''})
  $fieldsBoundaryCompact77=4
 }
 $statesBoundaryCompact77.Add(@{Name='emit';Tape=$loadedBoundaryCompact77;Fields=$fieldsBoundaryCompact77;Loaded=$true;Output='B'})
 foreach($stateBoundaryCompact77 in $statesBoundaryCompact77){
  [byte[]]$payloadBoundaryCompact77=@();if($stateBoundaryCompact77.Loaded){$payloadBoundaryCompact77=Bytes75 (('B'*$rows)+('B'*$stateBoundaryCompact77.Fields))}
  $expectedBoundaryCompact77=Join75 @((Bytes75 $stateBoundaryCompact77.Output),$stateBoundaryCompact77.Tape,(ModelMetric76))
  LongCheckT76 ('compact boundary '+$name+'/'+$stateBoundaryCompact77.Name) $expectedBoundaryCompact77 (Run75 ("training/compactlookup32-v1/$name-$($stateBoundaryCompact77.Name)-clean.probe.bf") $payloadBoundaryCompact77)
  foreach($faultBoundaryCompact77 in 'dirty','drift'){LongCheckT76 ('compact bad join '+$name+'/'+$stateBoundaryCompact77.Name+'/'+$faultBoundaryCompact77) $expectedBoundaryCompact77 (Run75 ("training/compactlookup32-v1/$name-$($stateBoundaryCompact77.Name)-$faultBoundaryCompact77.probe.bf") $payloadBoundaryCompact77) -Mismatch}
  Write-Host ('compact boundary '+$name+'/'+$stateBoundaryCompact77.Name)
 }
 $printerExpectedCompact77=Join75 @($seedBoundaryCompact77,(Bytes75 ('0'*(16*($rows+1)))),(ModelMetric76))
 LongCheckT76 ('compact bounded printer and zero second pass '+$name) $printerExpectedCompact77 (Run75 ("training/compactlookup32-v1/$name-printer-clean.probe.bf") ([byte[]]@()))
 foreach($faultBoundaryCompact77 in 'dirty','drift'){LongCheckT76 ('compact printer bad join '+$name+'/'+$faultBoundaryCompact77) $printerExpectedCompact77 (Run75 ("training/compactlookup32-v1/$name-printer-$faultBoundaryCompact77.probe.bf") ([byte[]]@())) -Mismatch}
 $streamInputBoundaryCompact77=Bytes75 (('B'*$rows)+('B'*$fieldsBoundaryCompact77));$streamExpectedBoundaryCompact77=Join75 @((Bytes75 'B1'),$loadedBoundaryCompact77,(ModelMetric76))
 LongCheckT76 ('compact stream boundary '+$name) $streamExpectedBoundaryCompact77 (Run75 ("training/compactlookup32-v1/$name-stream-clean.probe.bf") $streamInputBoundaryCompact77)
 foreach($faultBoundaryCompact77 in 'dirty','drift'){LongCheckT76 ('compact stream bad join '+$name+'/'+$faultBoundaryCompact77) $streamExpectedBoundaryCompact77 (Run75 ("training/compactlookup32-v1/$name-stream-$faultBoundaryCompact77.probe.bf") $streamInputBoundaryCompact77) -Mismatch}
}
function FixtureCompact77($name,$variant,[byte[]]$labels,[byte[]]$grid,[int]$fields,[switch]$Uncached){
 $rowsFixtureCompact77=$labels.Length;if($grid.Length -ne $rowsFixtureCompact77*$fields){throw 'Compact fixture framing'}
 $reverseGridFixtureCompact77=[byte[]]::new($grid.Length);$reverseLabelsFixtureCompact77=[byte[]]::new($labels.Length)
 for($rowFixtureCompact77=0;$rowFixtureCompact77 -lt $rowsFixtureCompact77;$rowFixtureCompact77++){[Array]::Copy($grid,($rowsFixtureCompact77-1-$rowFixtureCompact77)*$fields,$reverseGridFixtureCompact77,$rowFixtureCompact77*$fields,$fields);[Array]::Copy($labels,$rowsFixtureCompact77-1-$rowFixtureCompact77,$reverseLabelsFixtureCompact77,$rowFixtureCompact77,1)}
 $queriesFixtureCompact77=Join75 @($grid,$reverseGridFixtureCompact77,(Slice75 $grid 0 $fields),(Slice75 $grid ($grid.Length-$fields) $fields),(Slice75 $grid 0 $fields),(Slice75 $grid 0 $fields),(Slice75 $grid ($grid.Length-$fields) $fields))
 $predictionsFixtureCompact77=Join75 @($labels,$reverseLabelsFixtureCompact77,(Slice75 $labels 0 1),(Slice75 $labels ($labels.Length-1) 1),(Slice75 $labels 0 1),(Slice75 $labels 0 1),(Slice75 $labels ($labels.Length-1) 1))
 $inputFixtureCompact77=Join75 @($labels,$queriesFixtureCompact77);$expectedFixtureCompact77=Join75 @($predictionsFixtureCompact77,(Bytes75 '1'));$watchFixtureCompact77=[Diagnostics.Stopwatch]::StartNew()
 $actualFixtureCompact77=Run75 ("training/compactlookup32-v1/predict-$variant.bf") $inputFixtureCompact77 -Uncached:$Uncached;$watchFixtureCompact77.Stop()
 LongCheckT76 ('compact all ordered reversed repeated queries '+$name) $expectedFixtureCompact77 $actualFixtureCompact77
 $biasedFixtureCompact77=Run75 'training/freqlookup32-v1/labels-to-bias.bf' $labels;$bankFixtureCompact77=BankCompact77 $rowsFixtureCompact77 -BiasedLabels $biasedFixtureCompact77
 LongCheckT76 ('compact all resident and model cells preserved '+$name) (Join75 @($expectedFixtureCompact77,$bankFixtureCompact77,(ModelMetric76))) (Run75 ("training/compactlookup32-v1/predict-$variant-final.probe.bf") $inputFixtureCompact77)
 CheckC76 ('compact empty queries '+$name) (Bytes75 '1') (Run75 ("training/compactlookup32-v1/predict-$variant.bf") $labels)
 Save75 ($name+'.labels') $labels;Save75 ($name+'.queries') $queriesFixtureCompact77;Save75 ($name+'.input') $inputFixtureCompact77;Save75 ($name+'.predictions') $actualFixtureCompact77
 Json75 ($name+'.timing.json') @{Rows=$rowsFixtureCompact77;Queries=$predictionsFixtureCompact77.Length;ElapsedMilliseconds=$watchFixtureCompact77.ElapsedMilliseconds;Credit=0}
 Write-Host ('compact fixture '+$name+' rows='+$rowsFixtureCompact77+' queries='+$predictionsFixtureCompact77.Length+' primaryMs='+$watchFixtureCompact77.ElapsedMilliseconds)
 return @{Input=$inputFixtureCompact77;Expected=$expectedFixtureCompact77;Bank=$bankFixtureCompact77}
}
function PreflightCompact77(){
 & "$root/assemble-compactlookup32-v1.ps1" -Audit
 BoundariesCompact77 feature 450;BoundariesCompact77 quad 4096
 $gridsPreflightCompact77=GridsCompact77;$literalCycleCompact77=Bytes75 'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]'
 if($literalCycleCompact77.Length -ne 29){throw 'Compact literal cycle framing'}
 $featureLabelsCompact77=[byte[]]::new(450);$quadLabelsCompact77=[byte[]]::new(4096)
 for($ordinalLabelsCompact77=0;$ordinalLabelsCompact77 -lt 450;$ordinalLabelsCompact77++){[Array]::Copy($literalCycleCompact77,$ordinalLabelsCompact77%29,$featureLabelsCompact77,$ordinalLabelsCompact77,1)}
 for($ordinalLabelsCompact77=0;$ordinalLabelsCompact77 -lt 4096;$ordinalLabelsCompact77++){[Array]::Copy($literalCycleCompact77,$ordinalLabelsCompact77%29,$quadLabelsCompact77,$ordinalLabelsCompact77,1)}
 $featureFixtureCompact77=FixtureCompact77 feature-cycle feature $featureLabelsCompact77 $gridsPreflightCompact77.feature 2
 $quadFixtureCompact77=FixtureCompact77 quad-cycle quad $quadLabelsCompact77 $gridsPreflightCompact77.quad 4
 $compilerLabelsCompact77=[IO.File]::ReadAllBytes("$root/tests/countlabels32-preflight02-v1/mixed4096.labels");if($compilerLabelsCompact77.Length -ne 4096){throw 'Compact sealed compiler fixture framing'}
 $null=FixtureCompact77 quad-compiled quad $compilerLabelsCompact77 $gridsPreflightCompact77.quad 4
 $null=FixtureCompact77 quad-empty quad (Bytes75 ('A'*4096)) $gridsPreflightCompact77.quad 4 -Uncached
 $packetCompact77=Slice75 ([IO.File]::ReadAllBytes("$root/tests/textbatch32-preflight02-v1/selected71-hello.batch.input")) 0 336
 $nativeBaselineCompact77=Run75 'training/compactlookup32-v1/native-load-baseline.probe.bf' $packetCompact77
 foreach($nativeCaseCompact77 in @(@{Name='feature';Fixture=$featureFixtureCompact77},@{Name='quad';Fixture=$quadFixtureCompact77})){
  LongCheckT76 ('compact preserves loaded324 parameters header and model '+$nativeCaseCompact77.Name) (Join75 @($nativeCaseCompact77.Fixture.Expected,$nativeCaseCompact77.Fixture.Bank,$nativeBaselineCompact77)) (Run75 ("training/compactlookup32-v1/native-$($nativeCaseCompact77.Name)-preserved.probe.bf") (Join75 @($packetCompact77,$nativeCaseCompact77.Fixture.Input)))
 }
 Save75 native-model.baseline $nativeBaselineCompact77
 FinishDiag77 0 'compact16-cell resident feature450/quad4096 BF load and lookup,all addresses/full memory/loaded model preservation'
}
