# All numerical kernels and reference decisions are BF. Host routes fixed fields.
function RecentNativeQA8([byte[]]$contexts){
 $recent=[Collections.Generic.List[byte[]]]::new();foreach($context in (PartsRef76 $contexts 16)){$recent.Add((Slice75 $context 8 8))};return ,(Join75 $recent.ToArray())
}
function EncodeNativeQA8($name,[byte[]]$weights,[byte[]]$contexts){
 $blocks=PartsRef76 $contexts 8
 $payload=Join75 @((PacketCode77 $weights (Bytes75 '00000000')),(PayloadRef76 $blocks))
 $native=GuardLearn76 ($name+' eight BF embeddings') (Run75 'training/codevec32-v1/stream.bf' $payload) ($contexts.Length/2)
 LongCheckT76 ($name+' all eight embeddings independent') (ReferenceCode77 ($name+'-embed-reference') $weights $contexts) $native
 $older=[Collections.Generic.List[byte[]]]::new();$recent=[Collections.Generic.List[byte[]]]::new()
 foreach($row in (PartsRef76 $native 8)){$older.Add((Slice75 $row 0 4));$recent.Add((Slice75 $row 4 4))}
 $pooled=PoolQACodes8 (Join75 $older.ToArray()) (Join75 $recent.ToArray())
 Save75 ($name+'.eight.codes') $native;Save75 ($name+'.pooled.codes') $pooled
 return ,$pooled
}
function PayloadNativeQA8($model,[byte[]]$contexts,[byte[]]$codes,[switch]$Single){
 if($contexts.Length%16 -ne 0 -or $codes.Length -ne $contexts.Length/4){throw 'Native8 context/code framing'}
 if($Single){if($contexts.Length -ne 16){throw 'Native8 single context framing'};return ,(Join75 @((PayloadQANative32 $model (Slice75 $contexts 8 8) (Bytes75 '00')),$codes))}
 $rows=[Collections.Generic.List[byte[]]]::new()
 for($row=0;$row -lt $contexts.Length/16;$row++){$rows.Add((Join75 @((Slice75 $contexts (16*$row+8) 8),(Slice75 $codes (4*$row) 4))))}
 return ,(Join75 @((PayloadQANative32 $model (Bytes75 '00000000') (Bytes75 '00')),(PayloadRef76 $rows.ToArray())))
}
function ReferenceNativeQA8($name,$model,[byte[]]$contexts){
 if($contexts.Length -eq 0){return ,([byte[]]@())}
 $olderContexts=[Collections.Generic.List[byte[]]]::new();foreach($context in (PartsRef76 $contexts 16)){$olderContexts.Add((Slice75 $context 0 8))}
 $older=ReferenceCode77 ($name+'-older') $model.Weights (Join75 $olderContexts.ToArray())
 $recentContexts=RecentNativeQA8 $contexts
 $coarse=ReferenceHybrid77 ($name+'-recent') $model.Weights (Bytes75 ('A'*450)) (Bytes75 ('A'*4096)) $recentContexts
 $codes=[Collections.Generic.List[byte[]]]::new();$features=[Collections.Generic.List[byte[]]]::new()
 foreach($row in (PartsRef76 $coarse.Trace 7)){$codes.Add((Slice75 $row 0 4));$features.Add((Slice75 $row 4 2))}
 $pooled=ReferenceQAPool8 (PairsQAPool8 $older (Join75 $codes.ToArray()))
 $heads=ReadyQueriesHybrid77 ($name+'-pooled-heads') $model.FeatureLabels $model.FineLabels (Join75 $features.ToArray()) $pooled
 $keys=[Collections.Generic.List[byte[]]]::new();foreach($context in (PartsRef76 $contexts 16)){$keys.Add((Label75 (Slice75 $context 14 2)))}
 $last=GuardLearn76 ($name+' independent raw last') (ReferenceQABank32 $model.BigramLabels (Join75 $keys.ToArray())) ($contexts.Length/16)
 return ,(FusionReferenceHybrid77 ($name+'-last') $heads $last)
}
function FinalNativeQA8($name,$model,[byte[]]$contexts,[byte[]]$codes,[byte[]]$labels,[switch]$Single){
 $payload=PayloadNativeQA8 $model $contexts $codes -Single:$Single
 $final=Bytes75 '00000000';if($contexts.Length){$last=Slice75 $contexts ($contexts.Length-8) 8;$final=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @($last,(Bytes75 '00')))}
 $banks=BanksHybrid77 $model.FeatureLabels $model.FineLabels
 $groups=GroupsQANative32 (Join75 @($labels,(Bytes75 '1'))) (Bytes75 ('0'*192)) (BigramQANative32 $model.BigramLabels) (BaselineQANative32 $model.Weights $final) $banks.Feature $banks.Fine
 $variant=if($Single){'predict'}else{'stream'}
 foreach($group in 'aux','bigram','model','feature','fine'){LongCheckT76 ($name+' complete '+$group) $groups[$group] (Run75 ("training/wordqa-native8-v1/$variant-$group-final.probe.bf") $payload)}
}
function QueryNativeQA8($name,$model,[byte[]]$contexts,[switch]$Full,[switch]$Uncached){
 $codes=EncodeNativeQA8 $name $model.Weights $contexts;$reference=ReferenceNativeQA8 $name $model $contexts
 $payload=PayloadNativeQA8 $model $contexts $codes
 $native=GuardLearn76 ($name+' native8 stream guard') (Run75 'training/wordqa-native8-v1/stream.bf' $payload -Uncached:$Uncached) ($contexts.Length/16)
 LongCheckT76 ($name+' actual eight-word native predictions independent') $reference $native
 if($Full){FinalNativeQA8 $name $model $contexts $codes $native}
 Save75 ($name+'.native.input') $payload;Save75 ($name+'.native.labels') $native;Save75 ($name+'.reference.labels') $reference
 return @{Codes=$codes;Labels=$native}
}
function ReaderJoinNativeQA8($name,$model,[byte[]]$context){
 $codes=EncodeNativeQA8 ($name+'-encoding') $model.Weights $context;$payload=PayloadNativeQA8 $model $context $codes -Single
 # A before-reader probe must end at that boundary's input, so its EOF probe
 # sees EOF rather than the first code reserved for the not-yet-executed reader.
 $beforePayload=Slice75 $payload 0 ($payload.Length-4)
 $groups=@('aux','bigram','model','feature','fine');$before=@{};$after=@{}
 foreach($group in $groups){$before[$group]=Run75 ("training/wordqa-native8-v1/before-read-$group-clean.probe.bf") $beforePayload;$after[$group]=[byte[]]$before[$group].Clone()}
 $current=GuardLearn76 ($name+' current native E1 codes') (Run75 'training/codevec32-v1/codes.bf' (PacketCode77 $model.Weights (Slice75 $context 8 8))) 4
 $currentBiased=Run75 'training/freqlookup32-v1/labels-to-bias.bf' $current
 $pooledBiased=Run75 'training/freqlookup32-v1/labels-to-bias.bf' $codes
 $observed=[Collections.Generic.List[byte[]]]::new()
 for($column=0;$column -lt 4;$column++){$observed.Add((Slice75 $before.aux (144+2*$column) 1));[Array]::Copy($pooledBiased,$column,$after.aux,(144+2*$column),1)}
 CheckC76 ($name+' before reader holds original current codes') $currentBiased (Join75 $observed.ToArray())
 foreach($group in $groups){LongCheckT76 ($name+' reader preserves full '+$group) $after[$group] (Run75 ("training/wordqa-native8-v1/after-read-$group-clean.probe.bf") $payload)}
 foreach($state in @(@{Name='before-read';Expected=$before},@{Name='after-read';Expected=$after})){
  $expected=Join75 @($groups|ForEach-Object {$state.Expected[$_]})
  $probePayload=if($state.Name -ceq 'before-read'){$beforePayload}else{$payload}
  foreach($fault in 'dirty','drift'){
   $actual=[Collections.Generic.List[byte[]]]::new();foreach($group in $groups){$actual.Add((Run75 ("training/wordqa-native8-v1/$($state.Name)-$group-$fault.probe.bf") $probePayload))}
   LongCheckT76 ($name+' full reader bad join '+$state.Name+'/'+$fault) $expected (Join75 $actual.ToArray()) -Mismatch
  }
 }
}
