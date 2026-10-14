function LongCheckT76($name,[byte[]]$expected,[byte[]]$actual,[switch]$Mismatch){
 if($expected.Length -ne $actual.Length){if($Mismatch){CheckC76 $name $expected $actual -Mismatch;return};throw ('Table physical framing '+$name+' '+$expected.Length+'/'+$actual.Length)}
 $a=Bytes75 ([Convert]::ToBase64String($expected));$b=Bytes75 ([Convert]::ToBase64String($actual));$certificates=[Collections.Generic.List[byte[]]]::new();$required=[Collections.Generic.List[byte[]]]::new()
 for($outer=0;$outer -lt $a.Length;$outer+=50000){$count=[Math]::Min(50000,$a.Length-$outer);$blocks=[Collections.Generic.List[byte[]]]::new();for($offset=0;$offset -lt $count;$offset+=200){$n=[Math]::Min(200,$count-$offset);$blocks.Add((Join75 @((Bytes75 $n.ToString('000')),(Slice75 $a ($outer+$offset) $n),(Slice75 $b ($outer+$offset) $n))))};$payload=Join75 @((Bytes75 $blocks.Count.ToString('000')),(Join75 $blocks.ToArray()));$certificates.Add((Run75 'training/compat32-v11/verify-long.bf' $payload));$required.Add((Join75 @((Bytes75 ('0'*$blocks.Count)),([byte[]]@(0)))))}
 CheckC76 $name (Join75 $required.ToArray()) (Join75 $certificates.ToArray()) -Mismatch:$Mismatch
}
function SnapshotT76(){
 $tape=[byte[]](@(48)*57600);for($row=0;$row -lt 450;$row++){$tape[$row*128+7]=49};return ,$tape
}
function BoundariesT76(){
 $base=SnapshotT76;$outer=[byte[]]$base.Clone();$outer[1]=49;$inner=[byte[]]$outer.Clone();$inner[1923]=49;$label=[byte[]]$inner.Clone();$label[2065]=49;$klass=[byte[]]$inner.Clone();$klass[2066]=49;$increment=[byte[]]$klass.Clone();$increment[2068]=49;$classHome=[byte[]]$inner.Clone();$classHome[2068]=49;$innerHome=[byte[]]$outer.Clone();$innerHome[2068]=49;$homeTapeT76=[byte[]]$base.Clone();$homeTapeT76[2068]=49
 $states=@(@{Name='seed';Tape=$base;Output=''},@{Name='outer';Tape=$outer;Output=''},@{Name='inner';Tape=$inner;Output=''},@{Name='label';Tape=$label;Output=''},@{Name='class';Tape=$klass;Output=''},@{Name='increment';Tape=$increment;Output=''},@{Name='flag';Tape=$increment;Output='0'},@{Name='class-home';Tape=$classHome;Output='0'},@{Name='inner-home';Tape=$innerHome;Output='0'},@{Name='outer-home';Tape=$homeTapeT76;Output='0'},@{Name='stream';Tape=$homeTapeT76;Output='0'})
 foreach($state in $states){$expected=Join75 @((Bytes75 $state.Output),$state.Tape,(Bytes75 '11'));LongCheckT76 ('table boundary '+$state.Name) $expected (Run75 ("training/freqtable32-v1/"+$state.Name+'-clean.probe.bf') (Bytes75 'BBC'));foreach($damage in 'drift','dirty'){LongCheckT76 ('table bad boundary '+$state.Name+'/'+$damage) $expected (Run75 ("training/freqtable32-v1/"+$state.Name+'-'+$damage+'.probe.bf') (Bytes75 'BBC')) -Mismatch};Write-Host ('table76 boundary '+$state.Name)}
 $counts=Bytes75 ('AAAA'*12600);[Array]::Copy((Bytes75 'AAAB'),0,$counts,1796,4);$exportExpected=Join75 @((Bytes75 '0'),$counts,(Bytes75 '11'),$base,(Bytes75 '11'))
 LongCheckT76 'table export full cleanup' $exportExpected (Run75 'training/freqtable32-v1/export-clean.probe.bf' (Bytes75 'BBC'));foreach($damage in 'drift','dirty'){LongCheckT76 ('table export bad join '+$damage) $exportExpected (Run75 ("training/freqtable32-v1/export-$damage.probe.bf") (Bytes75 'BBC')) -Mismatch}
}
function ReferenceInputT76([byte[]]$triples){if($triples.Length%3 -ne 0){throw 'Table complete triples required'};$result=[byte[]]::new($triples.Length);for($offset=0;$offset -lt $triples.Length;$offset+=3){[Array]::Copy($triples,$offset+1,$result,$offset,1);[Array]::Copy($triples,$offset,$result,$offset+1,1);[Array]::Copy($triples,$offset+2,$result,$offset+2,1)};return ,$result}
function CanonicalReferenceT76([byte[]]$raw,$records){if($raw.Length -ne $records+50401){throw 'Reference table physical framing'};$result=[byte[]]::new(50400);for($x=0;$x -lt 30;$x++){for($y=0;$y -lt 15;$y++){[Array]::Copy($raw,$records+($y*30+$x)*112,$result,($x*15+$y)*112,112)}};return ,$result}
function TableFixtureT76($name,[byte[]]$triples,[byte[]]$expectedCounts,[switch]$Uncached){
 $records=$triples.Length/3;$clock=[Diagnostics.Stopwatch]::StartNew();$primary=Run75 'training/freqtable32-v1/fit.bf' $triples -Uncached:$Uncached;$reference=Run75 'training/freqtable32-v1/fit-reference.bf' (ReferenceInputT76 $triples);$clock.Stop();if($primary.Length -ne $records+50401 -or $reference.Length -ne $records+50401){throw ('Table fixture framing '+$name)}
 LongCheckT76 ($name+' primary overflow flags') (Bytes75 ('0'*$records)) (Slice75 $primary 0 $records);LongCheckT76 ($name+' reference overflow flags') (Bytes75 ('0'*$records)) (Slice75 $reference 0 $records)
 CheckC76 ($name+' primary guard') (Bytes75 '1') (Slice75 $primary ($primary.Length-1) 1);CheckC76 ($name+' reference guard') (Bytes75 '1') (Slice75 $reference ($reference.Length-1) 1)
 $canonical=Slice75 $primary $records 50400;$ref=CanonicalReferenceT76 $reference $records;LongCheckT76 ($name+' independent transposed table') $ref $canonical;LongCheckT76 ($name+' literal count table') $expectedCounts $canonical
 Save75 ($name+'.input') $triples;Save75 ($name+'.primary') $primary;Save75 ($name+'.reference') $reference;Save75 ($name+'.reference-canonical') $ref;Write-Host ('table76 fixture '+$name+' elapsedMs='+$clock.ElapsedMilliseconds)
}
function PreflightT76(){
 & "$root/assemble-freqtable32-v1.ps1" -Audit
 BoundariesT76
 $prior="$root/tests/freqcount32-preflight01-v1";$words=[IO.File]::ReadAllBytes("$prior/exhaustive.words");$nibbleReference=[IO.File]::ReadAllBytes("$prior/exhaustive.reference")
 for($chunk=0;$chunk -lt 16;$chunk++){$payload=Slice75 $words (16384*$chunk) 16384;$actual=Run75 'training/freqtable32-v1/pretest-stream.bf' $payload;LongCheckT76 ('pretest counter exhaustive '+$chunk) (Slice75 $nibbleReference (20480*$chunk) 20480) $actual};Write-Host 'table76 reference counter all65536 PASS'
 $empty=Bytes75 ('AAAA'*12600);TableFixtureT76 empty ([byte[]]@()) $empty
 $one=[byte[]]$empty.Clone();[Array]::Copy((Bytes75 'AAAB'),0,$one,0,4);TableFixtureT76 one (Bytes75 'AAB') $one
 $carry=[byte[]]$empty.Clone();[Array]::Copy((Bytes75 'ABAA'),0,$carry,0,4);TableFixtureT76 carry256 (Bytes75 ('AAB'*256)) $carry
 $mixed=[byte[]]$one.Clone();[Array]::Copy((Bytes75 'AAAB'),0,$mixed,1796,4);[Array]::Copy((Bytes75 'AAAB'),0,$mixed,50396,4);TableFixtureT76 mixed (Bytes75 'BBC^O]AAB') $mixed
 $overflow=Run75 'training/freqtable32-v1/overflow.bf' (Bytes75 'BBC');LongCheckT76 'table raw overflow is visible' (Join75 @((Bytes75 '1'),$empty,(Bytes75 '1'))) $overflow
 $grid=Run75 'training/freqtable32-v1/grid.bf' ([byte[]]@());if($grid.Length -ne 37800){throw 'Table BF grid framing'};CheckC76 'grid first triple' (Bytes75 'AAB') (Slice75 $grid 0 3);CheckC76 'grid last triple' (Bytes75 '^O]') (Slice75 $grid ($grid.Length-3) 3);$zero=[byte[]]::new(42);$zero[41]=49;LongCheckT76 'BF grid cleanup' (Join75 @($grid,$zero)) (Run75 'training/freqtable32-v1/grid-clean.probe.bf' ([byte[]]@()));Save75 exhaustive.grid $grid
 for($group=0;$group -lt 30;$group++){$expected=[byte[]]$empty.Clone();[Array]::Copy((Bytes75 ('AAAB'*420)),0,$expected,$group*1680,1680);TableFixtureT76 ('grid'+$group.ToString('00')) (Slice75 $grid ($group*1260) 1260) $expected}
 TableFixtureT76 uncached (Bytes75 'AAB') $one -Uncached
 $priorFlags=$script:assertions75.ToArray();CheckC76 'table component BF aggregate' ([byte[]](@(48)*$priorFlags.Length)) $priorFlags;Save75 aggregate.out $script:lastCertificate75;Save75 assertions.flags $script:assertions75.ToArray();[IO.File]::WriteAllLines("$data/assertions.manifest",$script:names75,$ascii);Json75 ledger.json @{Stage=76;Component='dense unsigned16 frequency table';Credit=0;Assertions=$script:assertions75.Count;ExpectedRefusals=$script:refusals75;PhysicalOrigins=$script:physical75;UncachedControls=$script:uncached75;FailedPhysical=$script:failed75;AddressedCountCells=12600;ReferenceCounterWords=65536;Aggregate='PASS';ValidationNumericalRuns=0;TestNumericalRuns=0;NeuralTrainingRuns=0};if($script:failed75 -ne 0){throw 'Table physical failure'}
}
