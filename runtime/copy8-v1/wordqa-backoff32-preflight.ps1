function ReferenceQABank32([byte[]]$labels,[byte[]]$queries){
 if($labels.Length -ne 32){throw 'QA reference bank label framing'}
 $keys='00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31'.Split(' ')
 $packets=[Collections.Generic.List[byte[]]]::new()
 foreach($query in (PartsRef76 $queries 1)){
  $decimal=IdGen76 $query
  for($row=0;$row -lt 32;$row++){$flag=Run75 'training/headobjective32-v11/error.bf' (Join75 @($decimal,(Bytes75 $keys[$row])));$packets.Add((Join75 @((Bytes75 '1'),$flag,(Slice75 $labels $row 1),([byte[]]@(0)))))}
 }
 $selected=Run75 'training/wordcodec32-v1/select-ids.bf' (Join75 $packets.ToArray());if($selected.Length -ne 2*$queries.Length){throw 'QA independent decimal bank selection framing'}
 $padding=[byte[]]::new($queries.Length);$predictions=[byte[]]::new($queries.Length)
 for($row=0;$row -lt $queries.Length;$row++){[Array]::Copy($selected,2*$row,$predictions,$row,1);[Array]::Copy($selected,(2*$row+1),$padding,$row,1)}
 LongCheckT76 'QA independent bank padding all NUL' ([byte[]]::new($queries.Length)) $padding
 return ,(Join75 @($predictions,(Bytes75 '1')))
}
function ProbeQABank32($name,[byte[]]$payload,[byte[]]$expected){
 LongCheckT76 ('QA32 bank boundary '+$name) $expected (Run75 ("training/wordqa-backoff32-v1/$name-clean.probe.bf") $payload)
 foreach($fault in 'dirty','drift'){LongCheckT76 ('QA32 bank damaged '+$name+'/'+$fault) $expected (Run75 ("training/wordqa-backoff32-v1/$name-$fault.probe.bf") $payload) -Mismatch}
}
function FixtureQABank32($name,[byte[]]$labels,[switch]$Uncached){
 $grid=Bytes75 'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`';if($grid.Length -ne 32 -or $labels.Length -ne 32){throw 'QA bank synthetic literal framing'}
 $reverseGrid=[byte[]]$grid.Clone();$reverseLabels=[byte[]]$labels.Clone();[Array]::Reverse($reverseGrid);[Array]::Reverse($reverseLabels)
 $edgeQueries=Bytes75 '`A^_`';$queries=Join75 @($grid,$reverseGrid,$grid,$edgeQueries)
 $inputPacket=Join75 @($labels,$queries);$actual=Run75 'training/wordqa-backoff32-v1/predict.bf' $inputPacket -Uncached:$Uncached
 $reference=ReferenceQABank32 $labels $queries;LongCheckT76 ($name+' independent decimal bank all queries') $reference $actual
 CheckC76 ($name+' literal full forward reverse and repeat') (Join75 @($labels,$reverseLabels,$labels)) (Slice75 $actual 0 96)
 $bank=BankCompact77 32 -BiasedLabels (Run75 'training/freqlookup32-v1/labels-to-bias.bf' $labels)
 LongCheckT76 ($name+' complete bank and model state') (Join75 @($reference,$bank,(ModelMetric76))) (Run75 'training/wordqa-backoff32-v1/predict-final.probe.bf' $inputPacket)
 CheckC76 ($name+' no-query stream') (Bytes75 '1') (Run75 'training/wordqa-backoff32-v1/predict.bf' $labels)
 LongCheckT76 ($name+' no-query complete state') (Join75 @((Bytes75 '1'),$bank,(ModelMetric76))) (Run75 'training/wordqa-backoff32-v1/predict-final.probe.bf' $labels)
 Save75 ($name+'.input') $inputPacket;Save75 ($name+'.output') $actual;Save75 ($name+'.reference') $reference;Save75 ($name+'.bank') $bank
 return @{Input=$inputPacket;Output=$reference;Bank=$bank}
}
function PreflightQABank32(){
 $seed=BankCompact77 32 -Seed;$loaded=BankCompact77 32 -BiasedLabels (Bytes75 ('1'*32));$blankModel=ModelMetric76
 ProbeQABank32 seed ([byte[]]@()) (Join75 @($seed,$blankModel))
 ProbeQABank32 load (Bytes75 ('B'*32)) (Join75 @($loaded,$blankModel))
 foreach($edge in @(@{ID='00';Index=0;Query='A'},@{ID='01';Index=1;Query='B'},@{ID='29';Index=29;Query='^'},@{ID='30';Index=30;Query='_'},@{ID='31';Index=31;Query='`'})){
  $payload=Bytes75 (('B'*32)+$edge.Query);$walk=[byte[]]$loaded.Clone()
  for($visited=0;$visited -lt $edge.Index;$visited++){$walk[16*$visited+1]=49}
  $copy=[byte[]]$walk.Clone();$copy[16*$edge.Index+9]=49;$returned=[byte[]]$loaded.Clone();$returned[9]=49
  foreach($step in @(@{Name='walk';State=$walk;Output=''},@{Name='copy';State=$copy;Output=''},@{Name='return';State=$returned;Output=''},@{Name='emit';State=$loaded;Output='B'})){
   ProbeQABank32 ($step.Name+$edge.ID) $payload (Join75 @((Bytes75 $step.Output),$step.State,$blankModel))
  }
 }
 ProbeQABank32 printer ([byte[]]@()) (Join75 @($seed,(Bytes75 ('0'*528)),$blankModel))
 ProbeQABank32 stream (Bytes75 (('B'*32)+'`')) (Join75 @((Bytes75 'B1'),$loaded,$blankModel))
 Write-Host 'QA32 last-ID bank all boundary edges PASS'
 $empty=FixtureQABank32 empty (Bytes75 ('A'*32)) -Uncached
 $mixed=FixtureQABank32 mixed (Bytes75 'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]ABC')
 $eos=FixtureQABank32 eos (Bytes75 ('B'*32))
 $weights=[IO.File]::ReadAllBytes("$root/release/wordbackoff80-v1/model/selected.weights")
 $packet=Join75 @((Bytes75 '110203040500'),$weights)
 $baseline=Run75 'training/compactlookup32-v1/native-load-baseline.probe.bf' $packet
 LongCheckT76 'QA32 bank preserves actual324 weights and all model cells' (Join75 @($mixed.Output,$mixed.Bank,$baseline)) (Run75 'training/wordqa-backoff32-v1/native-preserved.probe.bf' (Join75 @($packet,$mixed.Input)))
 # Literal new-ID embeddings; old E0 and E1 are zero. No training here.
 $tail=Slice75 $weights 64 260
 $allContexts=[Collections.Generic.List[byte[]]]::new();foreach($id in '00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31'.Split(' ')){$allContexts.Add((Bytes75 ($id*4)))}
 $contexts=Join75 $allContexts.ToArray()
 foreach($fixture in @(@{Name='zero';Triplet='000000';Literal='A'},@{Name='one';Triplet='010101';Literal='B'},@{Name='two';Triplet='020202';Literal='C'},@{Name='three';Triplet='030303';Literal='D'},@{Name='four';Triplet='040404';Literal='E'},@{Name='five';Triplet='050505';Literal='F'},@{Name='six';Triplet='060606';Literal='G'},@{Name='seven';Triplet='070707';Literal='H'})){
  $fixtureWeights=Join75 @((Bytes75 ('0'*58)),(Bytes75 $fixture.Triplet),$tail)
  FixtureCode77 ('new-ids-'+$fixture.Name) $fixtureWeights $contexts
  FixtureCode77 ('new-ids-preserve-'+$fixture.Name) $fixtureWeights $contexts -Preserve
  $literalExpected=Bytes75 (('A'*116)+($fixture.Literal*12))
  CheckC76 ('new-IDs literal code domains '+$fixture.Name) $literalExpected ([IO.File]::ReadAllBytes("$data/new-ids-$($fixture.Name).codes"))
 }
 foreach($fixture in @(@{Name='heterogeneous123';Triplet='010203';Literal='BCDBDCBCABDA'},@{Name='heterogeneous706';Triplet='070006';Literal='HAGHGAHAAHGA'})){
  $fixtureWeights=Join75 @((Bytes75 ('0'*58)),(Bytes75 $fixture.Triplet),$tail);$mixedContexts=Bytes75 '293031293130293000293100'
  FixtureCode77 $fixture.Name $fixtureWeights $mixedContexts -Uncached
  FixtureCode77 ($fixture.Name+'-preserve') $fixtureWeights $mixedContexts -Preserve
  CheckC76 ('new-IDs literal mixed positions '+$fixture.Name) (Bytes75 $fixture.Literal) ([IO.File]::ReadAllBytes("$data/$($fixture.Name).codes"))
 }
 $flags=$script:assertions75.ToArray();CheckC76 'QA bank and embeddings aggregate' (Bytes75 ('0'*$flags.Length)) $flags
 Save75 aggregate.out $script:lastCertificate75;Save75 assertions.flags $script:assertions75.ToArray();[IO.File]::WriteAllLines("$data/assertions.manifest",$script:names75,$ascii)
 Json75 ledger.json @{Status='PASS';Credit=0;Purpose='Full32 last-ID bank and question-ID embeddings';BankRows=32;BankCells=528;OutputDomain='empty0 or EOS/old words1..28';Assertions=$script:assertions75.Count;ExpectedRefusals=$script:refusals75;PhysicalOrigins=$script:physical75;FailedPhysical=$script:failed75;UncachedControls=$script:uncached75;Journals=$script:journals75.ToArray();CorpusTrainingRuns=0;ValidationNumericalRuns=0;TestNumericalRuns=0;NativeQAIntegration=$false;GoalComplete=$false}
 if($script:failed75 -ne 0){throw 'QA bank physical BF failure'}
}
