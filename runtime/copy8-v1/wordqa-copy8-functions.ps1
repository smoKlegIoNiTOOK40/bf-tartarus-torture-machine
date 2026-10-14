# Host fixed field/byte routing only. Teacher choices and resolution execute BF.
function EqualIDsCopyQA8([byte[][]]$left,[byte[]]$right){
 $packets=[Collections.Generic.List[byte[]]]::new()
 foreach($id in $left){
  if($id.Length -ne 2 -or $right.Length -ne 2){throw 'Copy8 equality framing'}
  $a=Join75 @($id,([byte[]]::new(6)));$b=Join75 @($right,([byte[]]::new(6)));$pair=[byte[]]::new(16)
  for($column=0;$column -lt 8;$column++){[Array]::Copy($a,$column,$pair,(2*$column),1);[Array]::Copy($b,$column,$pair,(2*$column+1),1)}
  $packets.Add($pair)
 }
 $matches=Run75 'training/wordcodec32-v1/equal8-stream.bf' (PayloadRef76 $packets.ToArray())
 if($matches.Length -ne $left.Count){throw 'Copy8 independent equality output framing'};return ,$matches
}
function TeacherFlagsCopyQA8([byte[]]$context,[byte[]]$target){
 if($context.Length -ne 16 -or $target.Length -ne 2){throw 'Copy8 teacher framing'}
 $keys=Join75 @((Bytes75 '0100'),$context);$errors=[Collections.Generic.List[byte[]]]::new()
 foreach($id in (PartsRef76 $keys 2)){$errors.Add((Run75 'training/headobjective32-v11/error.bf' (Join75 @($target,$id))))}
 return ,(Join75 $errors.ToArray())
}
function TeacherReferenceFlagsCopyQA8([byte[]]$context,[byte[]]$target){
 $matches=EqualIDsCopyQA8 (PartsRef76 (Join75 @((Bytes75 '0100'),$context)) 2) $target
 $reversed=[Collections.Generic.List[byte[]]]::new();$reversed.Add((Slice75 $matches 0 2))
 foreach($offset in @(9,8,7,6,5,4,3,2)){$reversed.Add((Slice75 $matches $offset 1))}
 return ,(Join75 $reversed.ToArray())
}
function TeachCopyQA8($name,[byte[]]$context,[byte[]]$target,[switch]$Uncached){
 $flags=TeacherFlagsCopyQA8 $context $target;$referenceFlags=TeacherReferenceFlagsCopyQA8 $context $target
 $primary=Run75 'training/wordqa-copy8-v1/teacher.bf' $flags -Uncached:$Uncached
 $reference=Run75 'training/wordqa-copy8-v1/teacher-reference.bf' $referenceFlags
 if($primary.Length -ne 2 -or $reference.Length -ne 2){throw 'Copy8 teacher action framing'}
 CheckC76 ($name+' copy teacher independent action/guard') $reference $primary
 CheckC76 ($name+' copy teacher guard') (Bytes75 '1') (Slice75 $primary 1 1)
 return ,(Slice75 $primary 0 1)
}
function ResolveReferenceCopyQA8([byte[]]$context,[byte[]]$action){
 $rows=PartsRef76 (Join75 @((Bytes75 '01'),$context)) 2;$keys=@('01','02','03','04','05','06','07','08','09')
 $packets=[Collections.Generic.List[byte[]]]::new()
 for($row=0;$row -lt 9;$row++){$errorFlag=Run75 'training/headobjective32-v11/error.bf' (Join75 @($action,(Bytes75 $keys[$row])));$packets.Add((Join75 @((Bytes75 '1'),$errorFlag,$rows[$row])))}
 $selected=Run75 'training/wordcodec32-v1/select-ids.bf' (Join75 $packets.ToArray())
 return ,(Run75 'training/wordqa-copy8-v1/normalize.bf' $selected)
}
function ResolveCopyQA8($name,[byte[]]$context,[byte[]]$action,[switch]$Uncached){
 if($context.Length -ne 16 -or $action.Length -ne 2){throw 'Copy8 resolver framing'}
 $primary=Run75 'training/wordqa-copy8-v1/resolver.bf' (Join75 @($action,(Bytes75 '01'),$context)) -Uncached:$Uncached
 $reference=ResolveReferenceCopyQA8 $context $action
 if($primary.Length -ne 3 -or $reference.Length -ne 3){throw 'Copy8 resolved word framing'}
 CheckC76 ($name+' copy resolver independent raw word/guard') $reference $primary
 CheckC76 ($name+' copy resolver guard') (Bytes75 '1') (Slice75 $primary 2 1)
 return ,(Slice75 $primary 0 2)
}
function ProbeCopyQA8($name,[byte[]]$payload,[byte[]]$expected){
 LongCheckT76 ('Copy8 full join '+$name) $expected (Run75 ("training/wordqa-copy8-v1/$name-clean.probe.bf") $payload)
 foreach($fault in 'dirty','drift'){LongCheckT76 ('Copy8 bad join '+$name+'/'+$fault) $expected (Run75 ("training/wordqa-copy8-v1/$name-$fault.probe.bf") $payload) -Mismatch}
}
