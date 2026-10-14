# Fixed byte routing only. Context shifting, coding and all checks execute BF.
function ReferenceShiftQAContext8([byte[]]$context,[byte[]]$target){
 if($context.Length -ne 16 -or $target.Length -ne 2){throw 'QA context8 reference shift framing'}
 $older=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @((Slice75 $context 0 8),(Slice75 $context 8 2)))
 $recent=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @((Slice75 $context 8 8),$target))
 return ,(Join75 @($older,$recent))
}
function ShiftQAContext8([byte[]]$context,[byte[]]$target){
 $shift=Run75 'training/wordqa-context8-v1/shift.bf' (Join75 @($context,$target))
 LongCheckT76 'QA context8 independent shift' (ReferenceShiftQAContext8 $context $target) $shift
 return ,$shift
}
function ReferenceRecordsQAContext8([byte[]]$question,[byte[]]$answer){
 $context=Bytes75 '0000000000000000'
 foreach($word in (PartsRef76 (Slice75 $question 2 ($question.Length-2)) 2)){$context=ReferenceShiftQAContext8 $context $word}
 $records=[Collections.Generic.List[byte[]]]::new()
 foreach($target in (PartsRef76 (Join75 @((Slice75 $answer 2 ($answer.Length-2)),(Bytes75 '01'))) 2)){
  $records.Add((Join75 @($context,$target)));$context=ReferenceShiftQAContext8 $context $target
 }
 return ,(Join75 $records.ToArray())
}
function AnswerRecordsQAContext8($name,[byte[]]$question,[byte[]]$answer){
 $questionIDs=EncodeQA32 ($name+'-question') $question;$answerIDs=EncodeQA32 ($name+'-answer') $answer
 $payload=Join75 @($questionIDs,$answerIDs);$records=Run75 'training/wordqa-context8-v1/records.bf' $payload
 LongCheckT76 ($name+' independent eight-word answer records') (ReferenceRecordsQAContext8 $questionIDs $answerIDs) $records
 Save75 ($name+'.question.raw') $question;Save75 ($name+'.answer.raw') $answer;Save75 ($name+'.records.input') $payload;Save75 ($name+'.answer.records') $records
 return ,$records
}
function StateQAContext8([byte[]]$raw){
 if($raw.Length -ne 90){throw 'QA context8 state framing'}
 $biased=BiasQA32 (Join75 @($raw,([byte[]]::new(6))))
 return ,(Join75 @((Slice75 $biased 0 90),([byte[]]@(0))))
}
function ProbeQAContext8($name,[byte[]]$payload,[byte[]]$expected){
 LongCheckT76 ('QA context8 full join '+$name) $expected (Run75 ("training/wordqa-context8-v1/$name-clean.probe.bf") $payload)
 foreach($fault in 'dirty','drift'){LongCheckT76 ('QA context8 bad join '+$name+'/'+$fault) $expected (Run75 ("training/wordqa-context8-v1/$name-$fault.probe.bf") $payload) -Mismatch}
}
