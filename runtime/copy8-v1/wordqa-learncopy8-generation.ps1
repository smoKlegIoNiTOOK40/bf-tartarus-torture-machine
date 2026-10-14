function QuestionContextCopyLearn8($name,[byte[]]$question){
 $record=AnswerRecordsQAContext8 $name $question ([byte[]]@());if($record.Length -ne 18){throw 'Copy generation question context framing'};return ,(Slice75 $record 0 16)
}
function AppendUserCopyLearn8($name,[byte[]]$context,[byte[]]$raw){
 $ids=EncodeQA32 $name $raw;$current=[byte[]]$context.Clone()
 Save75 ($name+'.history.before') $current
 foreach($word in (PartsRef76 (Slice75 $ids 2 ($ids.Length-2)) 2)){$current=ShiftQAContext8 $current $word}
 Save75 ($name+'.history.after') $current
 return ,$current
}
function GenerateCopyLearn8($name,$model,[byte[]]$context){
 $current=[byte[]]$context.Clone();$words=[Collections.Generic.List[byte[]]]::new();$actions=[Collections.Generic.List[byte[]]]::new();$text=[Collections.Generic.List[byte[]]]::new();$reason='L'
 for($step=0;$step -lt 7;$step++){
  if($model.Truncate){$current=Join75 @((Bytes75 '00000000'),(Slice75 $current 8 8))}
  $stepName=$name+'-step'+$step;Save75 ($stepName+'.context') $current
  $codes=EncodeNativeQA8 $stepName $model.Weights $current;$payload=PayloadNativeQA8 $model $current $codes -Single
  $action=GuardLearn76 ($stepName+' native action') (Run75 'training/wordqa-native8-v1/predict.bf' $payload) 1
  CheckC76 ($stepName+' independent native prediction') (ReferenceNativeQA8 $stepName $model $current) $action
  $actions.Add($action);$id=IdGen76 $action
  if($model.Kind -cne 'word'){$id=ResolveCopyQA8 $stepName $current $id}
  $words.Add($id);Save75 ($stepName+'.word') $id
  $invalid=Run75 'training/headobjective32-v11/error.bf' (Join75 @($id,(Bytes75 '00')))
  switch($ascii.GetString($invalid)){'0'{$reason='R'}'1'{}default{throw 'Copy generation invalid-word control domain'}}
  if($reason -ceq 'R'){break}
  $eos=Run75 'training/headobjective32-v11/error.bf' (Join75 @($id,(Bytes75 '01')))
  switch($ascii.GetString($eos)){'0'{$reason='E'}'1'{}default{throw 'Copy generation EOS control domain'}}
  if($reason -ceq 'E'){break}
  $text.Add((DecodeQA32 $id));$current=ShiftQAContext8 $current $id
 }
 $count=Run75 'training/texthybrid32-v1/sum-flags.bf' (Bytes75 ('1'*$words.Count));CheckC76 ($name+' actual call count guard/overflow') (Bytes75 '01') (Slice75 $count 4 2)
 $referenceCount=Run75 'training/textmetric32-v1/reference.bf' (Bytes75 ('AB'*$words.Count))
 CheckC76 ($name+' actual call count independent BF metric') (Slice75 $referenceCount ($referenceCount.Length-4) 4) (Slice75 $count 0 4)
 $raw=Join75 $words.ToArray();$padded=Join75 @($raw,(Bytes75 ('00'*(7-$words.Count))),(Bytes75 $reason))
 $plain=Join75 $text.ToArray();$nativeText=Join75 @($plain,(Bytes75 ('|'+$reason)),(Slice75 $count 0 4),(Bytes75 '1'))
 Save75 ($name+'.ids') $raw;Save75 ($name+'.actions') (Join75 $actions.ToArray());Save75 ($name+'.trace') $padded;Save75 ($name+'.text') $nativeText;Save75 ($name+'.history') $current
 return @{IDs=$raw;Trace=$padded;Text=$plain;Context=$current;Reason=$reason;Count=(Slice75 $count 0 4);HistoryFile=$name+'.history';TextFile=$name+'.text'}
}
function ExpectedTraceCopyLearn8($name,[byte[]]$answer){
 $ids=EncodeQA32 ($name+'-expected') $answer;$words=Join75 @((Slice75 $ids 2 ($ids.Length-2)),(Bytes75 '01'))
 if($words.Length -gt 14){throw 'Copy expected answer exceeds declared operational budget'}
 return ,(Join75 @($words,(Bytes75 ('0'*(14-$words.Length))),(Bytes75 'E')))
}
function CompareTraceCopyLearn8($name,[byte[]]$expected,[byte[]]$actual){
 if($expected.Length -ne 15 -or $actual.Length -ne 15){throw 'Copy exact trace framing'}
 $result=Run75 'training/compat32-v11/verify-long.bf' (Join75 @((Bytes75 '001015'),$expected,$actual))
 CheckC76 ($name+' exact BF comparison EOF') ([byte[]]@(0)) (Slice75 $result 1 1)
 return ,(Slice75 $result 0 1)
}
function SumErrorsCopyLearn8($name,[byte[]]$flags){
 $sum=Run75 'training/texthybrid32-v1/sum-flags.bf' $flags;CheckC76 ($name+' error sum guard/overflow') (Bytes75 '01') (Slice75 $sum 4 2)
 $decimal=if($flags.Length){SumFlags75 $flags ($name+'-decimal')}else{SumTriples75 ([byte[][]]@()) ($name+'-empty-decimal')}
 Save75 ($name+'.errors') $flags;Save75 ($name+'.word') (Slice75 $sum 0 4);Save75 ($name+'.decimal') $decimal
 return @{Word=(Slice75 $sum 0 4);Decimal=$decimal;Errors=$flags}
}
function ExactModelCopyLearn8($name,$model,$documents){
 $errors=[Collections.Generic.List[byte[]]]::new();$rows=[Collections.Generic.List[object]]::new();$familyFlags=@{};$linkedFlags=[Collections.Generic.List[byte[]]]::new()
 foreach($document in $documents){
  $stem=$name+'-'+$document.ID;$firstError=Bytes75 '0'
  if($document.Linked){
   $firstContext=QuestionContextCopyLearn8 ($stem+'-first-question') $document.FirstQuestionRaw
   $first=GenerateCopyLearn8 ($stem+'-first') $model $firstContext
   $firstError=CompareTraceCopyLearn8 ($stem+'-first') (ExpectedTraceCopyLearn8 ($stem+'-first') $document.FirstAnswerRaw) $first.Trace
   $context=AppendUserCopyLearn8 ($stem+'-followup') $first.Context (Bytes75 $document.Followup)
   Json75 ($stem+'.actual-history-origin.json') @{FirstActualHistoryFile=$first.HistoryFile;SHA256=(Get-FileHash -LiteralPath "$data/$($first.HistoryFile)").Hash;Followup=$document.Followup;GoldFirstAnswerUsedAsModelInput=$false;EOSExcludedFromHistory=$true}
  }else{$context=QuestionContextCopyLearn8 ($stem+'-question') $document.QuestionRaw}
  $generated=GenerateCopyLearn8 $stem $model $context
  $errorFlag=CompareTraceCopyLearn8 $stem (ExpectedTraceCopyLearn8 $stem $document.AnswerRaw) $generated.Trace
  $orPackets=[Collections.Generic.List[byte[]]]::new();$orPackets.Add((Join75 @($firstError,$errorFlag,(Bytes75 '0000'))))
  $joint=StreamEval76 any6 $orPackets.ToArray() 1
  $errors.Add($joint)
  if(-not $familyFlags.ContainsKey($document.Family)){$familyFlags[$document.Family]=[Collections.Generic.List[byte[]]]::new()};$familyFlags[$document.Family].Add($joint)
  if($document.Linked){$linkedFlags.Add($joint)}
  $rows.Add(@{ID=$document.ID;Family=$document.Family;Linked=$document.Linked;TextFile=$generated.TextFile;ActualHistoryFile=$generated.HistoryFile;ExactErrorFlag=$ascii.GetString($joint)})
 }
 $total=SumErrorsCopyLearn8 ($name+'-exact') (Join75 $errors.ToArray());$families=@{}
 foreach($family in $familyFlags.Keys){$part=SumErrorsCopyLearn8 ($name+'-'+$family) (Join75 $familyFlags[$family].ToArray());$families[$family]=@{Word=$part.Word;ErrorsDecimal=$ascii.GetString($part.Decimal);Documents=$familyFlags[$family].Count}}
 $linked=SumErrorsCopyLearn8 ($name+'-linked') (Join75 $linkedFlags.ToArray())
 Json75 ($name+'.answers.json') $rows.ToArray();return @{Word=$total.Word;Decimal=$total.Decimal;Errors=$total.Errors;Families=$families;Linked=$linked;Documents=$documents.Count}
}
function NoveltyCopyLearn8($name,[byte[]]$train,[byte[]]$external){
 $trainContexts=PartsRef76 (RouteLearning77 $train 18 0 16) 16;$externalContexts=PartsRef76 (RouteLearning77 $external 18 0 16) 16
 $flags=[Collections.Generic.List[byte[]]]::new();$blocks=[Collections.Generic.List[byte[]]]::new();$pairs=0
 foreach($query in $externalContexts){foreach($fit in $trainContexts){
  $blocks.Add((Join75 @((Bytes75 '016'),$query,$fit)));$pairs++
  if($blocks.Count -eq 250){$raw=Run75 'training/compat32-v11/verify-long.bf' (Join75 @((Bytes75 '250'),(Join75 $blocks.ToArray())));CheckC76 ($name+' novelty chunk EOF') ([byte[]]@(0)) (Slice75 $raw 250 1);$flags.Add((Slice75 $raw 0 250));$blocks.Clear()}
 }}
 if($blocks.Count){$raw=Run75 'training/compat32-v11/verify-long.bf' (Join75 @((Bytes75 $blocks.Count.ToString('000')),(Join75 $blocks.ToArray())));CheckC76 ($name+' novelty final EOF') ([byte[]]@(0)) (Slice75 $raw $blocks.Count 1);$flags.Add((Slice75 $raw 0 $blocks.Count))}
 $invert=[Collections.Generic.List[byte[]]]::new();foreach($different in (PartsRef76 (Join75 $flags.ToArray()) 1)){$invert.Add((Join75 @($different,(Bytes75 '1'))))}
 $equal=StreamEval76 invert $invert.ToArray() 1;$sum=Run75 'training/texthybrid32-v1/sum-flags.bf' $equal
 CheckC76 ($name+' novelty sum guard/overflow') (Bytes75 '01') (Slice75 $sum 4 2);CheckC76 ($name+' raw gold contexts absent from train') (Bytes75 'AAAA') (Slice75 $sum 0 4)
 Json75 ($name+'.context-novelty.json') @{ComparedInBF=$true;RawContextBytes=16;Pairs=$pairs;OverlapSafeWord=$ascii.GetString((Slice75 $sum 0 4));GoldContextDiagnostic=$true;ActualLinkedInputsUseActualGeneration=$true}
}
