function BanksHybrid77([byte[]]$feature,[byte[]]$fine){
 if($feature.Length -ne 450 -or $fine.Length -ne 4096){throw 'Hybrid table framing'}
 return @{Feature=(BankCompact77 450 -BiasedLabels (Run75 'training/freqlookup32-v1/labels-to-bias.bf' $feature));Fine=(BankCompact77 4096 -BiasedLabels (Run75 'training/freqlookup32-v1/labels-to-bias.bf' $fine))}
}
function SnapshotHybrid77([byte[]]$output,[byte[]]$aux,[byte[]]$feature,[byte[]]$fine,[byte[]]$model){
 if($aux.Length -ne 160 -or $feature.Length -ne 7216 -or $fine.Length -ne 65552 -or $model.Length -ne 2801){throw 'Hybrid snapshot framing'}
 return ,(Join75 @($output,$aux,$feature,$fine,$model))
}
function FusionReferenceHybrid77($name,[byte[]]$fine,[byte[]]$backup){
 if($fine.Length -ne $backup.Length){throw 'Hybrid paired reference framing'}
 $pairsFusionHybrid77=[Collections.Generic.List[byte[]]]::new()
 for($ordinalFusionHybrid77=0;$ordinalFusionHybrid77 -lt $fine.Length;$ordinalFusionHybrid77++){$pairsFusionHybrid77.Add((Join75 @((Slice75 $fine $ordinalFusionHybrid77 1),(Slice75 $backup $ordinalFusionHybrid77 1))))}
 $payloadFusionHybrid77=PayloadRef76 $pairsFusionHybrid77.ToArray()
 $chosenFusionHybrid77=GuardLearn76 ($name+' fusion reference') (Run75 'training/hybridnative32-v1/reference.bf' $payloadFusionHybrid77) $fine.Length
 Save75 ($name+'.fusion.input') $payloadFusionHybrid77;Save75 ($name+'.fusion.reference') $chosenFusionHybrid77
 return ,$chosenFusionHybrid77
}
function FusionHybrid77(){
 $alphabetFusionHybrid77=Bytes75 'ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]';$partsFusionHybrid77=[Collections.Generic.List[byte[]]]::new();$expectedPartsFusionHybrid77=[Collections.Generic.List[byte[]]]::new()
 foreach($fineOrdinalHybrid77 in 0..28){foreach($backupOrdinalHybrid77 in 1..28){$fineLiteralHybrid77=Slice75 $alphabetFusionHybrid77 $fineOrdinalHybrid77 1;$backupLiteralHybrid77=Slice75 $alphabetFusionHybrid77 $backupOrdinalHybrid77 1;$partsFusionHybrid77.Add((Join75 @($fineLiteralHybrid77,$backupLiteralHybrid77)));if($fineOrdinalHybrid77 -eq 0){$expectedPartsFusionHybrid77.Add($backupLiteralHybrid77)}else{$expectedPartsFusionHybrid77.Add($fineLiteralHybrid77)}}}
 $payloadFusionHybrid77=PayloadRef76 $partsFusionHybrid77.ToArray();$chosenFusionHybrid77=Join75 $expectedPartsFusionHybrid77.ToArray();$expectedFusionHybrid77=Join75 @($chosenFusionHybrid77,(Bytes75 '1'))
 LongCheckT76 'hybrid all812 literal fusion reference' $expectedFusionHybrid77 (Run75 'training/hybridnative32-v1/reference.bf' $payloadFusionHybrid77)
 LongCheckT76 'hybrid all812 native fusion' $expectedFusionHybrid77 (Run75 'training/hybridnative32-v1/fusion.bf' $payloadFusionHybrid77)
 LongCheckT76 'hybrid all812 reference complete workspace' (Join75 @($expectedFusionHybrid77,(ModelMetric76))) (Run75 'training/hybridnative32-v1/reference-final.probe.bf' $payloadFusionHybrid77)
 LongCheckT76 'hybrid all812 fusion complete workspace' (SnapshotHybrid77 $expectedFusionHybrid77 (Bytes75 ('0'*160)) (Bytes75 ('0'*7216)) (Bytes75 ('0'*65552)) (ModelMetric76)) (Run75 'training/hybridnative32-v1/fusion-final.probe.bf' $payloadFusionHybrid77)
 foreach($unitFusionHybrid77 in @(@{Name='empty-low';Pair='AB';Chosen='B'},@{Name='empty-high';Pair='A]';Chosen=']'},@{Name='fine-low';Pair='B]';Chosen='B'},@{Name='fine-high';Pair=']B';Chosen=']'})){
  $expectedUnitHybrid77=Join75 @((Bytes75 $unitFusionHybrid77.Chosen),(ModelMetric76));$payloadUnitHybrid77=Bytes75 $unitFusionHybrid77.Pair
  LongCheckT76 ('hybrid reference boundary '+$unitFusionHybrid77.Name) $expectedUnitHybrid77 (Run75 'training/hybridnative32-v1/reference-unit-clean.probe.bf' $payloadUnitHybrid77)
  foreach($faultUnitHybrid77 in 'dirty','drift'){LongCheckT76 ('hybrid reference bad join '+$unitFusionHybrid77.Name+'/'+$faultUnitHybrid77) $expectedUnitHybrid77 (Run75 ("training/hybridnative32-v1/reference-unit-$faultUnitHybrid77.probe.bf") $payloadUnitHybrid77) -Mismatch}
 }
 Save75 fusion812.input $payloadFusionHybrid77;Save75 fusion812.expected $expectedFusionHybrid77;Write-Host 'hybrid fusion all812 and full cleanup'
}
function BoundariesHybrid77([byte[]]$weights){
 $contextBoundaryHybrid77=Bytes75 '01020304';$packetBoundaryHybrid77=PacketCode77 $weights $contextBoundaryHybrid77;$featureLabelsBoundaryHybrid77=Bytes75 ('C'*450);$fineLabelsBoundaryHybrid77=Bytes75 ('A'*4096);$fineLabelsBoundaryHybrid77[668]=93
 $payloadBoundaryHybrid77=Join75 @($packetBoundaryHybrid77,$featureLabelsBoundaryHybrid77,$fineLabelsBoundaryHybrid77);$banksBoundaryHybrid77=BanksHybrid77 $featureLabelsBoundaryHybrid77 $fineLabelsBoundaryHybrid77
 $resetModelBoundaryHybrid77=BaselineCode77 $weights $contextBoundaryHybrid77;$backboneModelBoundaryHybrid77=Run75 'training/textmetric32-v1/oracle-backbone.bf' $packetBoundaryHybrid77;$hiddenModelBoundaryHybrid77=[byte[]]$backboneModelBoundaryHybrid77.Clone();$hiddenModelBoundaryHybrid77[1040]=48;$hiddenModelBoundaryHybrid77[1041]=48
 $independentBoundaryHybrid77=PipelineRef76 boundary-hybrid-reference $weights (Join75 @($contextBoundaryHybrid77,(Bytes75 '00')));$biasedHiddenHybrid77=Run75 'training/freqlookup32-v1/labels-to-bias.bf' (Slice75 $independentBoundaryHybrid77 0 2)
 $auxZeroHybrid77=Bytes75 ('0'*160);$auxCodesHybrid77=[byte[]]$auxZeroHybrid77.Clone();$auxCodesHybrid77[144]=49;$auxCodesHybrid77[146]=50;$auxCodesHybrid77[148]=51;$auxCodesHybrid77[150]=52
 $featureHiddenHybrid77=[byte[]]$banksBoundaryHybrid77.Feature.Clone();[Array]::Copy($biasedHiddenHybrid77,0,$featureHiddenHybrid77,0,1);[Array]::Copy($biasedHiddenHybrid77,1,$featureHiddenHybrid77,2,1)
 $featureBackupHybrid77=[byte[]]$banksBoundaryHybrid77.Feature.Clone();$featureBackupHybrid77[9]=50
 $fineRelayHybrid77=[byte[]]$banksBoundaryHybrid77.Fine.Clone();$fineRelayHybrid77[0]=49;$fineRelayHybrid77[2]=50;$fineRelayHybrid77[4]=51;$fineRelayHybrid77[6]=52
 $fineAHybrid77=[byte[]]$banksBoundaryHybrid77.Fine.Clone();$fineAHybrid77[1]=49;$fineAHybrid77[512*16+2]=50;$fineAHybrid77[512*16+4]=51;$fineAHybrid77[512*16+6]=52
 $fineBHybrid77=[byte[]]$banksBoundaryHybrid77.Fine.Clone();$fineBHybrid77[1]=49;foreach($rowBoundaryHybrid77 in 512,576){$fineBHybrid77[$rowBoundaryHybrid77*16+3]=49};$fineBHybrid77[640*16+4]=51;$fineBHybrid77[640*16+6]=52
 $fineCHybrid77=[byte[]]$banksBoundaryHybrid77.Fine.Clone();$fineCHybrid77[1]=49;foreach($rowBoundaryHybrid77 in 512,576){$fineCHybrid77[$rowBoundaryHybrid77*16+3]=49};foreach($rowBoundaryHybrid77 in 640,648,656){$fineCHybrid77[$rowBoundaryHybrid77*16+5]=49};$fineCHybrid77[664*16+6]=52
 $fineDHybrid77=[byte[]]$fineCHybrid77.Clone();$fineDHybrid77[664*16+6]=48;foreach($rowBoundaryHybrid77 in 664,665,666,667){$fineDHybrid77[$rowBoundaryHybrid77*16+7]=49}
 $fineCopyHybrid77=[byte[]]$fineDHybrid77.Clone();$fineCopyHybrid77[668*16+9]=76
 $fineReturnDHybrid77=[byte[]]$fineCHybrid77.Clone();$fineReturnDHybrid77[664*16+6]=48;$fineReturnDHybrid77[664*16+9]=76
 $fineReturnCHybrid77=[byte[]]$fineBHybrid77.Clone();$fineReturnCHybrid77[640*16+4]=48;$fineReturnCHybrid77[640*16+6]=48;$fineReturnCHybrid77[640*16+9]=76
 $fineReturnBHybrid77=[byte[]]$fineAHybrid77.Clone();foreach($fieldBoundaryHybrid77 in 2,4,6){$fineReturnBHybrid77[512*16+$fieldBoundaryHybrid77]=48};$fineReturnBHybrid77[512*16+9]=76
 $fineReturnAHybrid77=[byte[]]$banksBoundaryHybrid77.Fine.Clone();$fineReturnAHybrid77[9]=76
 $auxBackHybrid77=[byte[]]$auxZeroHybrid77.Clone();$auxBackHybrid77[144]=76
 $auxFusionHybrid77=[byte[]]$auxZeroHybrid77.Clone();$auxFusionHybrid77[149]=76;$auxFusionHybrid77[153]=50
 $statesBoundaryHybrid77=@(
  @{Name='heads';Aux=$auxZeroHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$resetModelBoundaryHybrid77;Output=''},
  @{Name='backbone';Aux=$auxCodesHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$backboneModelBoundaryHybrid77;Output=''},
  @{Name='hidden';Aux=$auxCodesHybrid77;Feature=$featureHiddenHybrid77;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='feature-query';Aux=$auxCodesHybrid77;Feature=$featureBackupHybrid77;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='relay-forward';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineRelayHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='a';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineAHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='b';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineBHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='c';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineCHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='d';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineDHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='copy';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineCopyHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='return-d';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineReturnDHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='return-c';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineReturnCHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='return-b';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineReturnBHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='return-a';Aux=$auxZeroHybrid77;Feature=$featureBackupHybrid77;Fine=$fineReturnAHybrid77;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='relay-back';Aux=$auxBackHybrid77;Feature=$featureBackupHybrid77;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='fusion-prepare';Aux=$auxFusionHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='fusion-fill';Aux=$auxFusionHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='fusion-drain';Aux=$auxBackHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=''},
  @{Name='emit';Aux=$auxZeroHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$hiddenModelBoundaryHybrid77;Output=']'},
  @{Name='reset';Aux=$auxZeroHybrid77;Feature=$banksBoundaryHybrid77.Feature;Fine=$banksBoundaryHybrid77.Fine;Model=$resetModelBoundaryHybrid77;Output=']'})
 foreach($stateBoundaryHybrid77 in $statesBoundaryHybrid77){
  $expectedBoundaryHybrid77=SnapshotHybrid77 (Bytes75 $stateBoundaryHybrid77.Output) $stateBoundaryHybrid77.Aux $stateBoundaryHybrid77.Feature $stateBoundaryHybrid77.Fine $stateBoundaryHybrid77.Model
  LongCheckT76 ('hybrid boundary '+$stateBoundaryHybrid77.Name) $expectedBoundaryHybrid77 (Run75 ("training/hybridnative32-v1/$($stateBoundaryHybrid77.Name)-clean.probe.bf") $payloadBoundaryHybrid77)
  foreach($faultBoundaryHybrid77 in 'dirty','drift'){LongCheckT76 ('hybrid bad join '+$stateBoundaryHybrid77.Name+'/'+$faultBoundaryHybrid77) $expectedBoundaryHybrid77 (Run75 ("training/hybridnative32-v1/$($stateBoundaryHybrid77.Name)-$faultBoundaryHybrid77.probe.bf") $payloadBoundaryHybrid77) -Mismatch}
  Write-Host ('hybrid complete boundary '+$stateBoundaryHybrid77.Name)
 }
 Save75 boundaries.input $payloadBoundaryHybrid77
}
function ReadyQueriesHybrid77($name,[byte[]]$featureLabels,[byte[]]$fineLabels,[byte[]]$features,[byte[]]$codes){
 if($features.Length%2 -ne 0 -or $codes.Length -ne 2*$features.Length){throw 'Hybrid ready query framing'}
 $backupQueryHybrid77=GuardLearn76 ($name+' compact backup') (Run75 'training/compactlookup32-v1/predict-feature.bf' (Join75 @($featureLabels,$features))) ($features.Length/2)
 $fineQueryHybrid77=GuardLearn76 ($name+' compact fine') (Run75 'training/compactlookup32-v1/predict-quad.bf' (Join75 @($fineLabels,$codes))) ($codes.Length/4)
 $chosenQueryHybrid77=FusionReferenceHybrid77 $name $fineQueryHybrid77 $backupQueryHybrid77
 Save75 ($name+'.features') $features;Save75 ($name+'.codes') $codes;Save75 ($name+'.backup') $backupQueryHybrid77;Save75 ($name+'.fine') $fineQueryHybrid77
 return ,$chosenQueryHybrid77
}
function LookupFixtureHybrid77($name,[byte[]]$featureLabels,[byte[]]$fineLabels,[byte[]]$features,[byte[]]$codes){
 $predictionsLookupHybrid77=ReadyQueriesHybrid77 $name $featureLabels $fineLabels $features $codes;$recordsLookupHybrid77=[Collections.Generic.List[byte[]]]::new()
 for($ordinalLookupHybrid77=0;$ordinalLookupHybrid77 -lt $predictionsLookupHybrid77.Length;$ordinalLookupHybrid77++){$recordsLookupHybrid77.Add((Join75 @((Slice75 $features (2*$ordinalLookupHybrid77) 2),(Slice75 $codes (4*$ordinalLookupHybrid77) 4))))}
 $payloadLookupHybrid77=Join75 @($featureLabels,$fineLabels,(PayloadRef76 $recordsLookupHybrid77.ToArray()));$expectedLookupHybrid77=Join75 @($predictionsLookupHybrid77,(Bytes75 '1'));$banksLookupHybrid77=BanksHybrid77 $featureLabels $fineLabels
 LongCheckT76 ($name+' all vector predictions') $expectedLookupHybrid77 (Run75 'training/hybridnative32-v1/lookup.bf' $payloadLookupHybrid77)
 LongCheckT76 ($name+' all vector final banks and memory') (SnapshotHybrid77 $expectedLookupHybrid77 (Bytes75 ('0'*160)) $banksLookupHybrid77.Feature $banksLookupHybrid77.Fine (ModelMetric76)) (Run75 'training/hybridnative32-v1/lookup-final.probe.bf' $payloadLookupHybrid77)
 Save75 ($name+'.input') $payloadLookupHybrid77;Save75 ($name+'.expected') $expectedLookupHybrid77;Write-Host ('hybrid vector fixture '+$name+' queries='+$predictionsLookupHybrid77.Length)
}
function ReferenceHybrid77($name,[byte[]]$weights,[byte[]]$featureLabels,[byte[]]$fineLabels,[byte[]]$contexts){
 if($contexts.Length%8 -ne 0){throw 'Hybrid native reference context framing'}
 $recordsReferenceHybrid77=[Collections.Generic.List[byte[]]]::new();foreach($contextReferenceHybrid77 in (PartsRef76 $contexts 8)){$recordsReferenceHybrid77.Add((Join75 @($contextReferenceHybrid77,(Bytes75 '00'))))}
 $triplesReferenceHybrid77=PipelineRef76 ($name+'-pipeline') $weights (Join75 $recordsReferenceHybrid77.ToArray());$embeddingReferenceHybrid77=[IO.File]::ReadAllBytes("$data/$name-pipeline.embed");$codesPartsReferenceHybrid77=[Collections.Generic.List[byte[]]]::new()
 foreach($pairReferenceHybrid77 in (PartsRef76 $embeddingReferenceHybrid77 2)){$codesPartsReferenceHybrid77.Add((Label75 $pairReferenceHybrid77))}
 $codesReferenceHybrid77=Join75 $codesPartsReferenceHybrid77.ToArray();$featuresReferenceHybrid77=[byte[]]::new(2*($contexts.Length/8))
 for($ordinalReferenceHybrid77=0;$ordinalReferenceHybrid77 -lt $contexts.Length/8;$ordinalReferenceHybrid77++){[Array]::Copy($triplesReferenceHybrid77,3*$ordinalReferenceHybrid77,$featuresReferenceHybrid77,2*$ordinalReferenceHybrid77,2)}
 $chosenReferenceHybrid77=ReadyQueriesHybrid77 $name $featureLabels $fineLabels $featuresReferenceHybrid77 $codesReferenceHybrid77;$tracePartsReferenceHybrid77=[Collections.Generic.List[byte[]]]::new()
 for($ordinalReferenceHybrid77=0;$ordinalReferenceHybrid77 -lt $contexts.Length/8;$ordinalReferenceHybrid77++){$tracePartsReferenceHybrid77.Add((Join75 @((Slice75 $codesReferenceHybrid77 (4*$ordinalReferenceHybrid77) 4),(Slice75 $featuresReferenceHybrid77 (2*$ordinalReferenceHybrid77) 2),(Slice75 $chosenReferenceHybrid77 $ordinalReferenceHybrid77 1))))}
 return @{Predictions=$chosenReferenceHybrid77;Trace=(Join75 $tracePartsReferenceHybrid77.ToArray())}
}
function FixtureHybrid77($name,[byte[]]$weights,[byte[]]$featureLabels,[byte[]]$fineLabels,[byte[]]$contexts,[switch]$Uncached){
 $initialContextHybrid77=Bytes75 '00000000';$payloadFixtureHybrid77=Join75 @((PacketCode77 $weights $initialContextHybrid77),$featureLabels,$fineLabels,(PayloadRef76 (PartsRef76 $contexts 8)));$referenceFixtureHybrid77=ReferenceHybrid77 $name $weights $featureLabels $fineLabels $contexts
 $expectedFixtureHybrid77=Join75 @($referenceFixtureHybrid77.Predictions,(Bytes75 '1'));$expectedTraceHybrid77=Join75 @($referenceFixtureHybrid77.Trace,(Bytes75 '1'));$watchFixtureHybrid77=[Diagnostics.Stopwatch]::StartNew()
 LongCheckT76 ($name+' native predictions independent') $expectedFixtureHybrid77 (Run75 'training/hybridnative32-v1/stream.bf' $payloadFixtureHybrid77 -Uncached:$Uncached);$watchFixtureHybrid77.Stop()
 LongCheckT76 ($name+' native codes features predictions independent') $expectedTraceHybrid77 (Run75 'training/hybridnative32-v1/trace.bf' $payloadFixtureHybrid77)
 $lastContextHybrid77=$initialContextHybrid77;if($contexts.Length -ne 0){$lastContextHybrid77=Slice75 $contexts ($contexts.Length-8) 8};$modelFixtureHybrid77=BaselineCode77 $weights $lastContextHybrid77;$banksFixtureHybrid77=BanksHybrid77 $featureLabels $fineLabels
 LongCheckT76 ($name+' final parameters banks navigation scratch') (SnapshotHybrid77 $expectedFixtureHybrid77 (Bytes75 ('0'*160)) $banksFixtureHybrid77.Feature $banksFixtureHybrid77.Fine $modelFixtureHybrid77) (Run75 'training/hybridnative32-v1/stream-final.probe.bf' $payloadFixtureHybrid77)
 LongCheckT76 ($name+' trace final parameters banks navigation scratch') (SnapshotHybrid77 $expectedTraceHybrid77 (Bytes75 ('0'*160)) $banksFixtureHybrid77.Feature $banksFixtureHybrid77.Fine $modelFixtureHybrid77) (Run75 'training/hybridnative32-v1/trace-final.probe.bf' $payloadFixtureHybrid77)
 Save75 ($name+'.input') $payloadFixtureHybrid77;Save75 ($name+'.contexts') $contexts;Save75 ($name+'.expected') $expectedFixtureHybrid77;Save75 ($name+'.trace.expected') $expectedTraceHybrid77;Save75 ($name+'.model.baseline') $modelFixtureHybrid77
 Json75 ($name+'.timing.json') @{Contexts=$contexts.Length/8;StreamAndCertificateMilliseconds=$watchFixtureHybrid77.ElapsedMilliseconds;Credit=0};Write-Host ('hybrid native fixture '+$name+' contexts='+($contexts.Length/8)+' elapsedMs='+$watchFixtureHybrid77.ElapsedMilliseconds)
}
function PreflightHybrid77(){
 & "$root/assemble-hybridnative32-v1.ps1" -Audit
 FusionHybrid77;$weightsPreflightHybrid77=WeightsCode77;BoundariesHybrid77 $weightsPreflightHybrid77.cycle
 $gridsPreflightHybrid77=GridsCompact77;$alphabetPreflightHybrid77=Bytes75 'BCDEFGHIJKLMNOPQRSTUVWXYZ[\]';$featureLabelsPreflightHybrid77=[byte[]]::new(450)
 for($ordinalPreflightHybrid77=0;$ordinalPreflightHybrid77 -lt 450;$ordinalPreflightHybrid77++){[Array]::Copy($alphabetPreflightHybrid77,($ordinalPreflightHybrid77%28),$featureLabelsPreflightHybrid77,$ordinalPreflightHybrid77,1)}
 $fineLabelsPreflightHybrid77=[IO.File]::ReadAllBytes("$root/tests/countlabels32-preflight02-v1/mixed4096.labels");$fallbackLabelsPreflightHybrid77=Bytes75 ('A'*4096)
 $featuresGridHybrid77=[byte[]]::new(8192);for($ordinalPreflightHybrid77=0;$ordinalPreflightHybrid77 -lt 4096;$ordinalPreflightHybrid77++){[Array]::Copy($gridsPreflightHybrid77.feature,2*($ordinalPreflightHybrid77%450),$featuresGridHybrid77,2*$ordinalPreflightHybrid77,2)}
 LookupFixtureHybrid77 vector4096-mixed $featureLabelsPreflightHybrid77 $fineLabelsPreflightHybrid77 $featuresGridHybrid77 $gridsPreflightHybrid77.quad
 LookupFixtureHybrid77 vector4096-fallback $featureLabelsPreflightHybrid77 $fallbackLabelsPreflightHybrid77 $featuresGridHybrid77 $gridsPreflightHybrid77.quad
 $mixedContextsPreflightHybrid77=[Collections.Generic.List[byte[]]]::new();foreach($idPreflightHybrid77 in 0..31){$mixedContextsPreflightHybrid77.Add((Bytes75 ($idPreflightHybrid77.ToString('00')*4)));$mixedContextsPreflightHybrid77.Add((Bytes75 ($idPreflightHybrid77.ToString('00')+(($idPreflightHybrid77+8)%32).ToString('00')+(($idPreflightHybrid77+16)%32).ToString('00')+(($idPreflightHybrid77+24)%32).ToString('00'))))};$mixedContextsHybrid77=Join75 $mixedContextsPreflightHybrid77.ToArray()
 FixtureHybrid77 all32-selected $weightsPreflightHybrid77.selected $featureLabelsPreflightHybrid77 $fineLabelsPreflightHybrid77 $mixedContextsHybrid77
 FixtureHybrid77 all32-zero-fallback $weightsPreflightHybrid77.zero $featureLabelsPreflightHybrid77 $fallbackLabelsPreflightHybrid77 $mixedContextsHybrid77
 FixtureHybrid77 all32-cycle $weightsPreflightHybrid77.cycle $featureLabelsPreflightHybrid77 $fineLabelsPreflightHybrid77 $mixedContextsHybrid77
 FixtureHybrid77 all32-reverse-fallback $weightsPreflightHybrid77.reverse $featureLabelsPreflightHybrid77 $fallbackLabelsPreflightHybrid77 $mixedContextsHybrid77
 $gridContextsHybrid77=Run75 'training/textkey64-v1/grid-codes.bf' ([byte[]]@());if($gridContextsHybrid77.Length -ne 32768){throw 'Hybrid frozen4096 contexts framing'}
 FixtureHybrid77 grid4096-cycle $weightsPreflightHybrid77.cycle $featureLabelsPreflightHybrid77 $fineLabelsPreflightHybrid77 $gridContextsHybrid77
 FixtureHybrid77 grid4096-reverse-fallback $weightsPreflightHybrid77.reverse $featureLabelsPreflightHybrid77 $fallbackLabelsPreflightHybrid77 $gridContextsHybrid77
 FixtureHybrid77 empty $weightsPreflightHybrid77.selected $featureLabelsPreflightHybrid77 $fineLabelsPreflightHybrid77 ([byte[]]@())
 FixtureHybrid77 repeated-uncached $weightsPreflightHybrid77.selected $featureLabelsPreflightHybrid77 $fineLabelsPreflightHybrid77 (Bytes75 ('31313131'*3)) -Uncached
 foreach($singlePreflightHybrid77 in @(@{Name='fine';Fine=(Bytes75 ('B'*4096));Expected='B1'},@{Name='fallback';Fine=$fallbackLabelsPreflightHybrid77;Expected='C1'})){
  $packetSingleHybrid77=PacketCode77 $weightsPreflightHybrid77.cycle (Bytes75 '01020304');$labelsSingleHybrid77=Bytes75 ('C'*450);$payloadSingleHybrid77=Join75 @($packetSingleHybrid77,$labelsSingleHybrid77,$singlePreflightHybrid77.Fine);$expectedSingleHybrid77=Bytes75 $singlePreflightHybrid77.Expected;$banksSingleHybrid77=BanksHybrid77 $labelsSingleHybrid77 $singlePreflightHybrid77.Fine
  CheckC76 ('hybrid single '+$singlePreflightHybrid77.Name) $expectedSingleHybrid77 (Run75 'training/hybridnative32-v1/predict.bf' $payloadSingleHybrid77)
  LongCheckT76 ('hybrid single final '+$singlePreflightHybrid77.Name) (SnapshotHybrid77 $expectedSingleHybrid77 (Bytes75 ('0'*160)) $banksSingleHybrid77.Feature $banksSingleHybrid77.Fine (BaselineCode77 $weightsPreflightHybrid77.cycle (Bytes75 '01020304'))) (Run75 'training/hybridnative32-v1/predict-final.probe.bf' $payloadSingleHybrid77)
 }
 FinishDiag77 0 'shared native backbone with preserving ordered E1 capture and resident4096 fine head;empty fallback to450 backbone head;independent BF code/feature/fusion checks,all addresses and complete memory'
}
