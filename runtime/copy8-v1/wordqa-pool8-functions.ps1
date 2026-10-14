function TableQAPool8 {
 $rows=@('ABCDEFGH','BCDEFGHA','CDEFGHAB','DEFGHABC','EFGHABCD','FGHABCDE','GHABCDEF','HABCDEFG')
 return ,(Bytes75 ((($rows|ForEach-Object {$_+'AAAAAAA'}) -join '')+('A'*330)))
}
function ReferenceQAPool8([byte[]]$pairs){
 if($pairs.Length%2 -ne 0){throw 'QA pool8 reference pair framing'}
 return ,(GuardLearn76 'QA pool8 independent cyclic table' (Run75 'training/compactlookup32-v1/predict-feature.bf' (Join75 @((TableQAPool8),$pairs))) ($pairs.Length/2))
}
function PairsQAPool8([byte[]]$older,[byte[]]$recent){
 if($older.Length -ne $recent.Length -or $older.Length%4 -ne 0){throw 'QA pool8 code blocks framing'}
 $pairs=[byte[]]::new(2*$older.Length)
 for($column=0;$column -lt $older.Length;$column++){[Array]::Copy($older,$column,$pairs,(2*$column),1);[Array]::Copy($recent,$column,$pairs,(2*$column+1),1)}
 return ,$pairs
}
function PoolQACodes8([byte[]]$older,[byte[]]$recent){
 $pairs=PairsQAPool8 $older $recent
 $pooled=GuardLearn76 'QA pool8 stream guard' (Run75 'training/wordqa-pool8-v1/stream.bf' $pairs) $older.Length
 LongCheckT76 'QA pool8 all pooled codes independent' (ReferenceQAPool8 $pairs) $pooled
 return ,$pooled
}
function ProbeQAPool8($name,[byte[]]$payload,[byte[]]$expected){
 LongCheckT76 ('QA pool8 full join '+$name) $expected (Run75 ("training/wordqa-pool8-v1/$name-clean.probe.bf") $payload)
 foreach($fault in 'dirty','drift'){LongCheckT76 ('QA pool8 bad join '+$name+'/'+$fault) $expected (Run75 ("training/wordqa-pool8-v1/$name-$fault.probe.bf") $payload) -Mismatch}
}
