function PacketCode77([byte[]]$weights,[byte[]]$context){if($weights.Length -ne 324 -or $context.Length -ne 8){throw 'Code vector packet framing'};return ,(Join75 @((Bytes75 '11'),$context,(Bytes75 '00'),$weights))}
function BaselineCode77([byte[]]$weights,[byte[]]$context){return ,(Run75 'training/textmetric32-v1/oracle-final-reset.bf' (PacketCode77 $weights $context))}
function WeightsCode77(){
 $selectedWeightsCode77=[IO.File]::ReadAllBytes("$root/tests/textlearn32-v2/selected.weights");$tailWeightsCode77=Slice75 $selectedWeightsCode77 64 260
 $cycleWeightsCode77=Bytes75 ('0001020304050607'+'0001020304050607'+'0001020304050607'+'0001020304'+'000000')
 $reverseWeightsCode77=Bytes75 ('0706050403020100'+'0706050403020100'+'0706050403020100'+'0706050403'+'000000')
 if($cycleWeightsCode77.Length -ne 64 -or $reverseWeightsCode77.Length -ne 64){throw 'Declared engineering embeddings framing'}
 return @{selected=$selectedWeightsCode77;zero=(Join75 @((Bytes75 ('0'*64)),$tailWeightsCode77));cycle=(Join75 @($cycleWeightsCode77,$tailWeightsCode77));reverse=(Join75 @($reverseWeightsCode77,$tailWeightsCode77))}
}
function ReferenceCode77($name,[byte[]]$weights,[byte[]]$contexts){
 if($contexts.Length%8 -ne 0){throw 'Code vector context framing'}
 $packetsReferenceCode77=[Collections.Generic.List[byte[]]]::new()
 for($offsetReferenceCode77=0;$offsetReferenceCode77 -lt $contexts.Length;$offsetReferenceCode77+=8){$contextReferenceCode77=Slice75 $contexts $offsetReferenceCode77 8;$packetReferenceCode77=PacketCode77 $weights $contextReferenceCode77;foreach($fieldReferenceCode77 in 0..3){$packetsReferenceCode77.Add((Join75 @((Slice75 $contextReferenceCode77 (2*$fieldReferenceCode77) 2),$packetReferenceCode77)))}}
 $pairsReferenceCode77=BatchRef76 embed $packetsReferenceCode77.ToArray() 2
 $zeroReferenceCode77=[byte[]]::new($pairsReferenceCode77.Length/2);$codesReferenceCode77=[Collections.Generic.List[byte[]]]::new()
 for($offsetPairCode77=0;$offsetPairCode77 -lt $pairsReferenceCode77.Length;$offsetPairCode77+=2){[Array]::Copy($pairsReferenceCode77,$offsetPairCode77,$zeroReferenceCode77,$offsetPairCode77/2,1);$codesReferenceCode77.Add((Label75 (Slice75 $pairsReferenceCode77 $offsetPairCode77 2)))}
 LongCheckT76 ($name+' independent E0 all zero') (Bytes75 ('0'*$zeroReferenceCode77.Length)) $zeroReferenceCode77
 Save75 ($name+'.reference.embedding') $pairsReferenceCode77
 return ,(Join75 $codesReferenceCode77.ToArray())
}
function FixtureCode77($name,[byte[]]$weights,[byte[]]$contexts,[switch]$Uncached,[switch]$Preserve){
 $programFixtureCode77='stream';if($Preserve){$programFixtureCode77='stream-preserve'}
 $contextsFixtureCode77=PartsRef76 $contexts 8;$initialFixtureCode77=Bytes75 '00000000';$payloadFixtureCode77=Join75 @((PacketCode77 $weights $initialFixtureCode77),(PayloadRef76 $contextsFixtureCode77));$expectedFixtureCode77=ReferenceCode77 $name $weights $contexts
 $watchFixtureCode77=[Diagnostics.Stopwatch]::StartNew();$actualFixtureCode77=GuardLearn76 $name (Run75 ("training/codevec32-v1/$programFixtureCode77.bf") $payloadFixtureCode77 -Uncached:$Uncached) $expectedFixtureCode77.Length;$watchFixtureCode77.Stop()
 LongCheckT76 ($name+' native ordered four codes independent') $expectedFixtureCode77 $actualFixtureCode77
 $finalContextFixtureCode77=$initialFixtureCode77;if($contexts.Length -ne 0){$finalContextFixtureCode77=Slice75 $contexts ($contexts.Length-8) 8}
 $baselineFixtureCode77=BaselineCode77 $weights $finalContextFixtureCode77
 LongCheckT76 ($name+' full model marker padding queue reset') (Join75 @($expectedFixtureCode77,(Bytes75 '1'),(Bytes75 ('0'*54)),$baselineFixtureCode77)) (Run75 ("training/codevec32-v1/$programFixtureCode77-final.probe.bf") $payloadFixtureCode77)
 Save75 ($name+'.input') $payloadFixtureCode77;Save75 ($name+'.contexts') $contexts;Save75 ($name+'.codes') $actualFixtureCode77;Save75 ($name+'.reference.codes') $expectedFixtureCode77;Save75 ($name+'.model.baseline') $baselineFixtureCode77
 Json75 ($name+'.timing.json') @{Contexts=$contextsFixtureCode77.Count;Codes=$expectedFixtureCode77.Length;NativeElapsedMilliseconds=$watchFixtureCode77.ElapsedMilliseconds;Credit=0}
 Write-Host ('native code fixture '+$name+' contexts='+$contextsFixtureCode77.Count+' nativeMs='+$watchFixtureCode77.ElapsedMilliseconds)
}
function BoundariesCode77([byte[]]$weights){
 $contextBoundaryCode77=Bytes75 '01020304';$packetBoundaryCode77=PacketCode77 $weights $contextBoundaryCode77;$baseBoundaryCode77=BaselineCode77 $weights $contextBoundaryCode77;$chunkBoundaryCode77=Bytes75 ('0'*54)
 $copyBoundaryCode77=[byte[]]$baseBoundaryCode77.Clone();$copyBoundaryCode77[124]=49;$copyBoundaryCode77[125]=50;$copyBoundaryCode77[126]=51;$copyBoundaryCode77[127]=52
 $openBoundaryCode77=[byte[]]$copyBoundaryCode77.Clone();$openBoundaryCode77[129]=52
 $embeddingBoundaryCode77=[byte[]]$openBoundaryCode77.Clone();$embeddingBoundaryCode77[124]=48;$embeddingBoundaryCode77[8]=49
 $captureBoundaryCode77=[byte[]]$embeddingBoundaryCode77.Clone();$captureBoundaryCode77[8]=48;$captureChunkCode77=[byte[]]$chunkBoundaryCode77.Clone();$captureChunkCode77[50]=49
 $shiftBoundaryCode77=[byte[]]$captureBoundaryCode77.Clone();$shiftBoundaryCode77[124]=50;$shiftBoundaryCode77[125]=51;$shiftBoundaryCode77[126]=52;$shiftBoundaryCode77[127]=48
 $kernelChunkCode77=[byte[]]$chunkBoundaryCode77.Clone();$kernelChunkCode77[44]=49;$kernelChunkCode77[46]=50;$kernelChunkCode77[48]=51;$kernelChunkCode77[50]=52
 $statesBoundaryCode77=@(@{Name='load-reset';Model=$baseBoundaryCode77;Chunk=$chunkBoundaryCode77;Output=''},@{Name='context-copy';Model=$copyBoundaryCode77;Chunk=$chunkBoundaryCode77;Output=''},@{Name='project-open';Model=$openBoundaryCode77;Chunk=$chunkBoundaryCode77;Output=''},@{Name='embedding';Model=$embeddingBoundaryCode77;Chunk=$chunkBoundaryCode77;Output=''},@{Name='capture';Model=$captureBoundaryCode77;Chunk=$captureChunkCode77;Output=''},@{Name='cache-shift';Model=$shiftBoundaryCode77;Chunk=$captureChunkCode77;Output=''},@{Name='kernel';Model=$baseBoundaryCode77;Chunk=$kernelChunkCode77;Output=''},@{Name='emit';Model=$baseBoundaryCode77;Chunk=$chunkBoundaryCode77;Output='BCDE'},@{Name='final-reset';Model=$baseBoundaryCode77;Chunk=$chunkBoundaryCode77;Output='BCDE'})
 foreach($stateBoundaryCode77 in $statesBoundaryCode77){$expectedBoundaryCode77=Join75 @((Bytes75 $stateBoundaryCode77.Output),$stateBoundaryCode77.Chunk,$stateBoundaryCode77.Model);LongCheckT76 ('code vector boundary '+$stateBoundaryCode77.Name) $expectedBoundaryCode77 (Run75 ("training/codevec32-v1/$($stateBoundaryCode77.Name)-clean.probe.bf") $packetBoundaryCode77);foreach($faultBoundaryCode77 in 'dirty','drift'){LongCheckT76 ('code vector bad join '+$stateBoundaryCode77.Name+'/'+$faultBoundaryCode77) $expectedBoundaryCode77 (Run75 ("training/codevec32-v1/$($stateBoundaryCode77.Name)-$faultBoundaryCode77.probe.bf") $packetBoundaryCode77) -Mismatch};Write-Host ('native code boundary '+$stateBoundaryCode77.Name)}
 foreach($valuePreserveCode77 in 0..7){$contextPreserveCode77=Bytes75 ($valuePreserveCode77.ToString('00')+'020304');$modelPreserveCode77=[byte[]](BaselineCode77 $weights $contextPreserveCode77).Clone();$modelPreserveCode77[8]=48+$valuePreserveCode77;$modelPreserveCode77[125]=50;$modelPreserveCode77[126]=51;$modelPreserveCode77[127]=52;$modelPreserveCode77[129]=52;$chunkPreserveCode77=[byte[]]$chunkBoundaryCode77.Clone();$chunkPreserveCode77[50]=48+$valuePreserveCode77;$expectedPreserveCode77=Join75 @($chunkPreserveCode77,$modelPreserveCode77);$packetPreserveCode77=PacketCode77 $weights $contextPreserveCode77;LongCheckT76 ('code vector preserve E1 value '+$valuePreserveCode77) $expectedPreserveCode77 (Run75 'training/codevec32-v1/preserve-capture-clean.probe.bf' $packetPreserveCode77);foreach($faultPreserveCode77 in 'dirty','drift'){LongCheckT76 ('code vector preserve bad join '+$valuePreserveCode77+'/'+$faultPreserveCode77) $expectedPreserveCode77 (Run75 ("training/codevec32-v1/preserve-capture-$faultPreserveCode77.probe.bf") $packetPreserveCode77) -Mismatch}}
 $initialStreamCode77=PacketCode77 $weights (Bytes75 '00000000');$initialModelStreamCode77=BaselineCode77 $weights (Bytes75 '00000000')
 foreach($stateStreamCode77 in @(@{Name='open';Input=(Join75 @($initialStreamCode77,(Bytes75 '1')));Model=$initialModelStreamCode77;Output=''},@{Name='header';Input=(Join75 @($initialStreamCode77,(Bytes75 '101020304')));Model=$baseBoundaryCode77;Output=''},@{Name='kernel';Input=(Join75 @($initialStreamCode77,(Bytes75 '101020304')));Model=$baseBoundaryCode77;Output='BCDE'},@{Name='next';Input=(Join75 @($initialStreamCode77,(Bytes75 '101020304')));Model=$baseBoundaryCode77;Output='BCDE1'})){$expectedStreamCode77=Join75 @((Bytes75 $stateStreamCode77.Output),$chunkBoundaryCode77,$stateStreamCode77.Model);LongCheckT76 ('code vector stream boundary '+$stateStreamCode77.Name) $expectedStreamCode77 (Run75 ("training/codevec32-v1/stream-$($stateStreamCode77.Name)-clean.probe.bf") $stateStreamCode77.Input);foreach($faultStreamCode77 in 'dirty','drift'){LongCheckT76 ('code vector stream bad join '+$stateStreamCode77.Name+'/'+$faultStreamCode77) $expectedStreamCode77 (Run75 ("training/codevec32-v1/stream-$($stateStreamCode77.Name)-$faultStreamCode77.probe.bf") $stateStreamCode77.Input) -Mismatch};Write-Host ('native code stream boundary '+$stateStreamCode77.Name)}
}
function PreflightCode77(){
 & "$root/assemble-codevec32-v1.ps1" -Audit
 $weightsPreflightCode77=WeightsCode77;BoundariesCode77 $weightsPreflightCode77.cycle
 $mixedPreflightCode77=[Collections.Generic.List[byte[]]]::new()
 foreach($idPreflightCode77 in 0..31){$mixedPreflightCode77.Add((Bytes75 ($idPreflightCode77.ToString('00')*4)));$mixedPreflightCode77.Add((Bytes75 ($idPreflightCode77.ToString('00')+(($idPreflightCode77+8)%32).ToString('00')+(($idPreflightCode77+16)%32).ToString('00')+(($idPreflightCode77+24)%32).ToString('00'))))}
 $mixedContextsCode77=Join75 $mixedPreflightCode77.ToArray()
 FixtureCode77 all32-selected $weightsPreflightCode77.selected $mixedContextsCode77
 FixtureCode77 all32-zero $weightsPreflightCode77.zero $mixedContextsCode77
 FixtureCode77 all32-cycle $weightsPreflightCode77.cycle $mixedContextsCode77
 FixtureCode77 all32-reverse $weightsPreflightCode77.reverse $mixedContextsCode77
 $gridPreflightCode77=Run75 'training/textkey64-v1/grid-codes.bf' ([byte[]]@());if($gridPreflightCode77.Length -ne 32768){throw 'Code vector frozen4096 grid framing'}
 FixtureCode77 grid4096-cycle $weightsPreflightCode77.cycle $gridPreflightCode77
 FixtureCode77 grid4096-reverse $weightsPreflightCode77.reverse $gridPreflightCode77
 FixtureCode77 grid4096-preserve $weightsPreflightCode77.cycle $gridPreflightCode77 -Preserve
 FixtureCode77 empty $weightsPreflightCode77.selected ([byte[]]@())
 FixtureCode77 repeated-uncached $weightsPreflightCode77.selected (Bytes75 ('31313131'*3)) -Uncached
 $singleCode77=Run75 'training/codevec32-v1/codes.bf' (PacketCode77 $weightsPreflightCode77.cycle (Bytes75 '01020304'));CheckC76 'native single literal ordered codes' (Bytes75 'BCDE1') $singleCode77
 LongCheckT76 'native single final full model and queue' (Join75 @((Bytes75 'BCDE1'),(Bytes75 ('0'*54)),(BaselineCode77 $weightsPreflightCode77.cycle (Bytes75 '01020304')))) (Run75 'training/codevec32-v1/codes-final.probe.bf' (PacketCode77 $weightsPreflightCode77.cycle (Bytes75 '01020304')))
 FinishDiag77 0 'native ordered E1 extraction before positions/attention;independent BF embedding lookup,all32 IDs,all4096 code tuples and full state'
}
