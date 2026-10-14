function ReferenceQARecords32([byte[]]$question,[byte[]]$answer){
 $questionWindows=Run75 'training/textdata32-v1/windows.bf' $question;$context=Slice75 $questionWindows ($questionWindows.Length-10) 8
 $targets=Join75 @((Slice75 $answer 2 ($answer.Length-2)),(Bytes75 '01'));$reference=[Collections.Generic.List[byte[]]]::new()
 foreach($target in (PartsRef76 $targets 2)){$reference.Add((Join75 @($context,$target)));$context=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @($context,$target))}
 return ,(Join75 $reference.ToArray())
}
function AnswerRecordsQA32($name,[byte[]]$question,[byte[]]$answer){
 $questionIDs=EncodeQA32 ($name+'-question') $question;$answerIDs=EncodeQA32 ($name+'-answer') $answer
 $recordPayload=Join75 @($questionIDs,$answerIDs);$records=Run75 'training/wordqa-records32-v1/records.bf' $recordPayload
 LongCheckT76 ($name+' answer-only targets independent BF') (ReferenceQARecords32 $questionIDs $answerIDs) $records
 Save75 ($name+'.question.raw') $question;Save75 ($name+'.answer.raw') $answer;Save75 ($name+'.records.input') $recordPayload;Save75 ($name+'.answer.records') $records
 return ,$records
}
function RecordStateQA32([byte[]]$raw){if($raw.Length -ne 70){throw 'QA record state framing'};$biased=BiasQA32 (Join75 @($raw,([byte[]]::new(2))));return ,(Join75 @((Slice75 $biased 0 70),([byte[]]@(0))))}
function ProbeQARecords32($name,[byte[]]$recordPayload,[byte[]]$expected){
 LongCheckT76 ('QA answer record boundary '+$name) $expected (Run75 ("training/wordqa-records32-v1/$name-clean.probe.bf") $recordPayload)
 foreach($fault in 'dirty','drift'){LongCheckT76 ('QA answer record bad join '+$name+'/'+$fault) $expected (Run75 ("training/wordqa-records32-v1/$name-$fault.probe.bf") $recordPayload) -Mismatch}
}
function PreflightQARecords32(){
 $clean=[byte[]]::new(70);$clean[64]=1;$seed=[byte[]]$clean.Clone();[Array]::Copy((Bytes75 '00000000'),0,$seed,1,8)
 ProbeQARecords32 seed ([byte[]]@()) (RecordStateQA32 $seed)
 $qHeader=[byte[]]$seed.Clone();$qHeader[0]=5;ProbeQARecords32 question-header (Bytes75 '05') (RecordStateQA32 $qHeader)
 $question=Bytes75 '052907111417';$answer=Bytes75 '0102';$skipped=[byte[]]$clean.Clone();[Array]::Copy((Bytes75 '07111417'),0,$skipped,1,8)
 ProbeQARecords32 question-skip $question (RecordStateQA32 $skipped)
 $aHeader=[byte[]]$skipped.Clone();$aHeader[0]=1;ProbeQARecords32 answer-header (Join75 @($question,(Bytes75 '01'))) (RecordStateQA32 $aHeader)
 $literal=Bytes75 '07111417021114170201';ProbeQARecords32 complete (Join75 @($question,$answer)) (Join75 @($literal,(RecordStateQA32 $clean)))
 $cases=@(
  @{Name='empty';Q=(Bytes75 '00');A=(Bytes75 '00');Expected='0000000001'},
  @{Name='who-empty-answer';Q=(Bytes75 '0129');A=(Bytes75 '00');Expected='0000002901'},
  @{Name='question-five-answer-one';Q=$question;A=$answer;Expected='07111417021114170201'},
  @{Name='empty-question-new-answers';Q=(Bytes75 '00');A=(Bytes75 '03293031');Expected='0000000029000000293000002930310029303101'},
  @{Name='short-context-preserved';Q=(Bytes75 '022930');A=(Bytes75 '0131');Expected='00002930310029303101'},
  @{Name='repeated';Q=(Bytes75 '051111111111');A=(Bytes75 '021111');Expected='111111111111111111111111111101'},
  @{Name='maximum-question';Q=(Bytes75 ('99'+('293031'*33)));A=(Bytes75 '0102');Expected=$null},
  @{Name='maximum-answer';Q=(Bytes75 '00');A=(Bytes75 ('99'+('293031'*33)));Expected=$null},
  @{Name='both-maximum';Q=(Bytes75 ('99'+('293031'*33)));A=(Bytes75 ('99'+('293031'*33)));Expected=$null}
 )
 foreach($case in $cases){
  $recordPayload=Join75 @($case.Q,$case.A);$records=Run75 'training/wordqa-records32-v1/records.bf' $recordPayload;$reference=ReferenceQARecords32 $case.Q $case.A
  LongCheckT76 ('QA answer records independent '+$case.Name) $reference $records
  if($null -ne $case.Expected){CheckC76 ('QA answer records literal '+$case.Name) (Bytes75 $case.Expected) $records}
  ProbeQARecords32 complete $recordPayload (Join75 @($reference,(RecordStateQA32 $clean)))
  Save75 ($case.Name+'.input') $recordPayload;Save75 ($case.Name+'.records') $records;Save75 ($case.Name+'.reference') $reference
 }
 $resident=[byte[]]$clean.Clone();$resident[20]=255;$resident[50]=122;$resident[69]=201
 LongCheckT76 'QA answer records preserve foreign memory' (Join75 @($literal,(RecordStateQA32 $resident))) (Run75 'training/wordqa-records32-v1/resident-complete.probe.bf' (Join75 @($resident,$question,$answer)))
 CheckC76 'QA answer records uncached' $literal (Run75 'training/wordqa-records32-v1/records.bf' (Join75 @($question,$answer)) -Uncached)
 foreach($case in @(
  @{Name='raw-who';Q='who carries a red key';A='mira';Expected='07111417021114170201'},
  @{Name='raw-what';Q='mira carries what';A='a red key';Expected='0002073011020730111407301114173011141701'},
  @{Name='raw-where';Q='mira rests where';A='near the bench';Expected='0002103123021031231210312312283123122801'},
  @{Name='raw-empty';Q='';A='';Expected='0000000001'}
 )){CheckC76 ('QA raw answer adapter literal '+$case.Name) (Bytes75 $case.Expected) (AnswerRecordsQA32 $case.Name (Bytes75 $case.Q) (Bytes75 $case.A))}
 $before=$script:assertions75.ToArray();CheckC76 'QA answer record aggregate' (Bytes75 ('0'*$before.Length)) $before
 Save75 aggregate.out $script:lastCertificate75;Save75 assertions.flags $script:assertions75.ToArray();[IO.File]::WriteAllLines("$data/assertions.manifest",$script:names75,$ascii)
 Json75 ledger.json @{Status='PASS';Credit=0;Purpose='Answer-only word records engineering';Assertions=$script:assertions75.Count;ExpectedRefusals=$script:refusals75;PhysicalOrigins=$script:physical75;FailedPhysical=$script:failed75;UncachedControls=$script:uncached75;Journals=$script:journals75.ToArray();CorpusTrainingRuns=0;ValidationNumericalRuns=0;TestNumericalRuns=0;GoalComplete=$false}
 if($script:failed75 -ne 0){throw 'QA records physical failure'}
}
