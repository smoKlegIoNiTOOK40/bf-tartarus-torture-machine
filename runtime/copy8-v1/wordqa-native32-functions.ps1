# QA host framing only. Numeric reference, inference, choice and counts are BF.
function PacketQANative32([byte[]]$weights,[byte[]]$context,[byte[]]$budget){
 if($weights.Length -ne 324 -or $context.Length -ne 8 -or $budget.Length -ne 2){throw 'QA native packet framing'}
 foreach($id in (PartsRef76 $context 2)){CheckC76 'QA native context slot domain' (Bytes75 '0') (Run75 'training/abi32-v11/validate-slot.bf' $id)}
 return ,(Join75 @((Bytes75 '10'),$context,$budget,$weights))
}
function PayloadQANative32($model,[byte[]]$context,[byte[]]$budget,[switch]$Generation,[byte[]]$Contexts){
 if($model.FeatureLabels.Length -ne 450 -or $model.FineLabels.Length -ne 4096 -or $model.BigramLabels.Length -ne 32){throw 'QA native heads framing'}
 $parts=[Collections.Generic.List[byte[]]]::new();$parts.Add((PacketQANative32 $model.Weights $context $budget));$parts.Add($model.FeatureLabels);$parts.Add($model.FineLabels);$parts.Add($model.BigramLabels)
 if($Generation){$parts.Add((BankQA32))}elseif($null -ne $Contexts){$parts.Add((PayloadRef76 (PartsRef76 $Contexts 8)))}
 return ,(Join75 $parts.ToArray())
}
function BaselineQANative32([byte[]]$weights,[byte[]]$context){return ,(Run75 'training/textmetric32-v1/oracle-final-reset.bf' (PacketQANative32 $weights $context (Bytes75 '00')))}
function CodecQANative32(){return ,(Slice75 (StateQA32 (BankQA32) (Bytes75 ('0'*24))) 4000 275)}
function BigramQANative32([byte[]]$labels){return ,(BankCompact77 32 -BiasedLabels (Run75 'training/freqlookup32-v1/labels-to-bias.bf' $labels))}
function GroupsQANative32([byte[]]$output,[byte[]]$aux,[byte[]]$bigram,[byte[]]$model,[byte[]]$feature,[byte[]]$fine,[byte[]]$codec){
 if($aux.Length -ne 192 -or $bigram.Length -ne 528 -or $model.Length -ne 2801 -or $feature.Length -ne 7216 -or $fine.Length -ne 65552){throw 'QA native region framing'}
 $groups=@{aux=(Join75 @($output,$aux,([byte[]]@(0))));bigram=(Join75 @($output,$bigram,([byte[]]@(0))));model=(Join75 @($output,$model));feature=(Join75 @($output,$feature,([byte[]]@(0))));fine=(Join75 @($output,$fine,([byte[]]@(0))))}
 if($null -ne $codec){if($codec.Length -ne 275){throw 'QA native codec region framing'};$groups.codec=Join75 @($output,$codec,(Bytes75 ('0'*110)),([byte[]]@(0)))}
 return $groups
}
function QueryReferenceQANative32($name,$model,[byte[]]$contexts){
 if($contexts.Length%8 -ne 0){throw 'QA native reference contexts framing'}
 if($contexts.Length -eq 0){return ,([byte[]]@())}
 $coarse=ReferenceHybrid77 ($name+'-heads') $model.Weights $model.FeatureLabels $model.FineLabels $contexts
 $queries=[Collections.Generic.List[byte[]]]::new();foreach($context in (PartsRef76 $contexts 8)){$queries.Add((Label75 (Slice75 $context 6 2)))}
 $bigram=GuardLearn76 ($name+' independent32 key scan') (ReferenceQABank32 $model.BigramLabels (Join75 $queries.ToArray())) ($contexts.Length/8)
 return ,(FusionReferenceHybrid77 ($name+'-last-backup') $coarse.Predictions $bigram)
}
function GenerateReferenceQANative32($name,$model,[byte[]]$context,[int]$limit){
 if($limit -lt 0 -or $limit -gt 99){throw 'QA declared generation limit'}
 $labels=[Collections.Generic.List[byte[]]]::new();$text=[Collections.Generic.List[byte[]]]::new();$current=$context;$reason='L'
 for($step=0;$step -lt $limit;$step++){
  $label=QueryReferenceQANative32 ($name+'-step'+$step) $model $current;$id=IdGen76 $label
  $labels.Add($label);$text.Add((ReferenceDecodeQA32 $id (BankQA32)))
  $current=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @($current,$id))
  $eos=Run75 'training/headobjective32-v11/error.bf' (Join75 @($id,(Bytes75 '01')))
  switch($ascii.GetString($eos)){'0'{$reason='E'}'1'{}default{throw 'QA BF EOS reference domain'}}
  if($reason -ceq 'E'){break}
 }
 $allLabels=Join75 $labels.ToArray();$count=Run75 'training/texthybrid32-v1/sum-flags.bf' (Bytes75 ('1'*$allLabels.Length));CheckC76 ($name+' reference count guard/status') (Bytes75 '01') (Slice75 $count 4 2)
 return @{Labels=$allLabels;Text=(Join75 $text.ToArray());Context=$current;Reason=$reason;Word=(Slice75 $count 0 4)}
}
function CompleteGenerationQANative32($name,$model,[byte[]]$context,[byte[]]$budget,[int]$limit,[switch]$Full,[switch]$Uncached){
 $reference=GenerateReferenceQANative32 $name $model $context $limit;$outputs=OutputsGeneration77 $reference
 $payload=PayloadQANative32 $model $context $budget -Generation
 foreach($variant in 'text','trace'){
  $expected=$outputs.Text;if($variant -ceq 'trace'){$expected=$outputs.Trace}
  $actual=Run75 ("training/wordqa-native32-v1/$variant.bf") $payload -Uncached:($Uncached -and $variant -ceq 'text')
  LongCheckT76 ($name+' native '+$variant+' output and stop/count') $expected $actual;Save75 ($name+'.'+$variant) $actual
  if($Full){
   $banks=BanksHybrid77 $model.FeatureLabels $model.FineLabels
   $groups=GroupsQANative32 $expected (Bytes75 ('0'*192)) (BigramQANative32 $model.BigramLabels) (BaselineQANative32 $model.Weights $reference.Context) $banks.Feature $banks.Fine (CodecQANative32)
   foreach($group in 'aux','bigram','model','codec','feature','fine'){LongCheckT76 ($name+' '+$variant+' complete '+$group) $groups[$group] (Run75 ("training/wordqa-native32-v1/$variant-$group-final.probe.bf") $payload)}
  }
 }
 # Direct single-context batch must produce the same first label as generation.
 if($limit -gt 0){$single=GuardLearn76 ($name+' direct batch') (Run75 'training/wordqa-native32-v1/predict.bf' (PayloadQANative32 $model $context (Bytes75 '00'))) 1;CheckC76 ($name+' actual batch/generation first label') (Slice75 $reference.Labels 0 1) $single}
 Save75 ($name+'.input') $payload;Save75 ($name+'.reference.labels') $reference.Labels;Save75 ($name+'.reference.context') $reference.Context
 $script:qaNativeGenerationCases++;return $reference
}
function CompleteBatchQANative32($name,$model,[byte[]]$initial,[byte[]]$contexts,[switch]$Full,[switch]$Uncached){
 $reference=QueryReferenceQANative32 $name $model $contexts;$expected=Join75 @($reference,(Bytes75 '1'))
 $payload=PayloadQANative32 $model $initial (Bytes75 '00') -Contexts $contexts;$actual=Run75 'training/wordqa-native32-v1/stream.bf' $payload -Uncached:$Uncached
 LongCheckT76 ($name+' batch all predictions independent') $expected $actual
 if($Full){
  $final=$initial;if($contexts.Length){$final=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @((Slice75 $contexts ($contexts.Length-8) 8),(Bytes75 '00')))}
  $banks=BanksHybrid77 $model.FeatureLabels $model.FineLabels;$groups=GroupsQANative32 $expected (Bytes75 ('0'*192)) (BigramQANative32 $model.BigramLabels) (BaselineQANative32 $model.Weights $final) $banks.Feature $banks.Fine
  foreach($group in 'aux','bigram','model','feature','fine'){LongCheckT76 ($name+' batch final '+$group) $groups[$group] (Run75 ("training/wordqa-native32-v1/stream-$group-final.probe.bf") $payload)}
 }
 for($row=0;$row -lt $reference.Length;$row++){
  $context=Slice75 $contexts (8*$row) 8;$label=Slice75 $reference $row 1;$id=IdGen76 $label
  $stop=Run75 'training/headobjective32-v11/error.bf' (Join75 @($id,(Bytes75 '01')));$reason=if($ascii.GetString($stop) -ceq '0'){'E'}else{'L'}
  $trace=Join75 @($label,(Bytes75 ('|'+$reason+'AAAB1')))
  CheckC76 ($name+' actual stream/generation label '+$row) $trace (Run75 'training/wordqa-native32-v1/trace.bf' (PayloadQANative32 $model $context (Bytes75 '01') -Generation))
 }
 Save75 ($name+'.input') $payload;Save75 ($name+'.output') $actual;Save75 ($name+'.reference') $reference;$script:qaNativeBatchCases++
 return ,$reference
}
function BoundaryGroupsQANative32($prefix,$caseName,$stateName,[byte[]]$payload,$groups){
 $names=@('aux','bigram','model','feature','fine');if($prefix -ceq 'gen'){$names=@('aux','bigram','model','codec','feature','fine')}
 $expected=[Collections.Generic.List[byte[]]]::new()
 foreach($group in $names){$expected.Add($groups[$group]);LongCheckT76 ('QA '+$prefix+' '+$caseName+'/'+$stateName+'/'+$group) $groups[$group] (Run75 ("training/wordqa-native32-v1/$prefix-$stateName-$group-clean.probe.bf") $payload)}
 foreach($fault in 'dirty','drift'){$actual=[Collections.Generic.List[byte[]]]::new();foreach($group in $names){$actual.Add((Run75 ("training/wordqa-native32-v1/$prefix-$stateName-$group-$fault.probe.bf") $payload))};LongCheckT76 ('QA '+$prefix+' bad '+$caseName+'/'+$stateName+'/'+$fault) (Join75 $expected.ToArray()) (Join75 $actual.ToArray()) -Mismatch}
 Write-Host ('QA native boundary '+$prefix+'/'+$caseName+'/'+$stateName)
}
