# Host routing and literal dictionary rows. Every token decision executes as BF.
function RowQA32([string]$word){$row=[byte[]]::new(8);$raw=Bytes75 $word;if($raw.Length -gt 7){throw 'QA dictionary row width'};[Array]::Copy($raw,0,$row,0,$raw.Length);return ,$row}
function VocabQA32(){return (Get-Content -LiteralPath "$root/training/wordqa-codec32-v1/vocabulary.json" -Raw|ConvertFrom-Json)}
function BankQA32(){return ,(Join75 @((VocabQA32)|ForEach-Object {RowQA32 $_.Word}))}
function PackQA32([byte[]]$raw,[int]$width){$parts=[Collections.Generic.List[byte[]]]::new();foreach($part in (PartsRef76 $raw $width)){$parts.Add((Bytes75 '1'));$parts.Add($part)};return ,(Join75 $parts.ToArray())}
function BiasQA32([byte[]]$raw){return ,(Run75 'training/wordcodec32-v1/read-eight-dump.bf' (PackQA32 $raw 8))}
function SmallQA32(){return ,(Join75 @((Bytes75 ('0'*64)),(Bytes75 '1'),(Bytes75 ('0'*5)),([byte[]]@(0))))}
function StateQA32([byte[]]$bank,[byte[]]$header){if($bank.Length -ne 248 -or $header.Length -ne 24){throw 'QA resident state framing'};return ,(Join75 @((Bytes75 ('0'*4000)),$header,(BiasQA32 $bank),(Bytes75 '10'),([byte[]]@(0))))}
function ProbeQA32($name,[byte[]]$payload,[byte[]]$expected){
 LongCheckT76 ('QA boundary '+$name) $expected (Run75 ("training/wordqa-codec32-v1/$name-clean.probe.bf") $payload)
 foreach($fault in 'dirty','drift'){LongCheckT76 ('QA boundary refusal '+$name+'/'+$fault) $expected (Run75 ("training/wordqa-codec32-v1/$name-$fault.probe.bf") $payload) -Mismatch}
}
function CompareQA32([byte[]]$words,[byte[]]$bank){
 if($words.Length%8 -ne 0 -or $bank.Length -ne 248){throw 'QA lookup framing'}
 $primary=[Collections.Generic.List[byte[]]]::new();$reference=[Collections.Generic.List[byte[]]]::new()
 foreach($left in (PartsRef76 $words 8)){foreach($right in (PartsRef76 $bank 8)){
  $primary.Add((Join75 @((Bytes75 '008'),$left,$right)))
  $pair=[byte[]]::new(16);for($offset=0;$offset -lt 8;$offset++){[Array]::Copy($left,$offset,$pair,(2*$offset),1);[Array]::Copy($right,$offset,$pair,(2*$offset+1),1)};$reference.Add($pair)
 }}
 if($primary.Count -eq 0){return @{Errors=[byte[]]@();Equal=[byte[]]@()}}
 $errors=CompareEval76 $primary.ToArray();$equal=Run75 'training/wordcodec32-v1/equal8-stream.bf' (PayloadRef76 $reference.ToArray())
 $invert=[Collections.Generic.List[byte[]]]::new();foreach($flag in (PartsRef76 $equal 1)){$invert.Add((Join75 @($flag,(Bytes75 '1'))))}
 LongCheckT76 'QA independent eight byte comparisons' (StreamEval76 invert $invert.ToArray() 1) $errors
 return @{Errors=$errors;Equal=$equal}
}
function LookupQA32($name,[byte[]]$words,[byte[]]$bank){
 $comparison=CompareQA32 $words $bank;$vocab=VocabQA32;$selector=[Collections.Generic.List[byte[]]]::new()
 for($query=0;$query -lt $words.Length/8;$query++){for($row=0;$row -lt 31;$row++){$selector.Add((Join75 @((Bytes75 '1'),(Slice75 $comparison.Errors (31*$query+$row) 1),(Bytes75 $vocab[$row].ID))))}}
 $ids=Run75 'training/wordcodec32-v1/select-ids.bf' (Join75 $selector.ToArray())
 $reference=Run75 'training/wordqa-codec32-v1/lookup-reference.bf' (PackQA32 $comparison.Equal 31)
 if($reference.Length -ne 2*($words.Length/8)){throw 'QA reference lookup framing'}
 $referenceIDs=[Collections.Generic.List[byte[]]]::new();$counts=[Collections.Generic.List[byte[]]]::new()
 foreach($fields in (PartsRef76 $reference 2)){$referenceIDs.Add((IdGen76 (Slice75 $fields 0 1)));$counts.Add((Slice75 $fields 1 1))}
 Save75 ($name+'.lookup.reference') $reference;Save75 ($name+'.lookup.errors') $comparison.Errors
 return @{IDs=$ids;ReferenceIDs=(Join75 $referenceIDs.ToArray());Counts=(Join75 $counts.ToArray())}
}
function EncodeQA32($name,[byte[]]$text){
 if($text.Length -gt 98){throw 'QA text physical cap'}
 $counted=Counted75 $text;CheckC76 ($name+' raw alphabet') (Bytes75 '0') (Run75 'training/codec32-v11/validate-text.bf' $counted)
 $lexed=Run75 'training/wordcodec32-v1/lex.bf' $counted;if($lexed.Length -lt 1 -or ($lexed.Length-1)%8 -ne 0){throw 'QA lexer framing'}
 CheckC76 ($name+' canonical words') (Bytes75 '0') (Slice75 $lexed ($lexed.Length-1) 1)
 $words=Slice75 $lexed 0 ($lexed.Length-1);$lookup=LookupQA32 $name $words (BankQA32)
 if($lookup.IDs.Length -ne 2*($words.Length/8)){throw 'QA BF dictionary refused unknown or ambiguous word'}
 LongCheckT76 ($name+' unique BF matches') (Bytes75 ('B'*($words.Length/8))) $lookup.Counts
 LongCheckT76 ($name+' independent ordinal IDs') $lookup.ReferenceIDs $lookup.IDs
 $count=Run75 'training/codec32-v11/metadata-to-count.bf' (Bytes75 (($lookup.IDs.Length/2).ToString()+[char]10));CheckC76 ($name+' BF count header') (Bytes75 '0') (Slice75 $count 0 1)
 $result=Join75 @((Slice75 $count 1 2),$lookup.IDs);Save75 ($name+'.word.rows') $words;Save75 ($name+'.ids') $result;return ,$result
}
function ReferenceDecodeQA32([byte[]]$id,[byte[]]$bank){
 $rows=[Collections.Generic.List[byte[]]]::new();$vocab=VocabQA32
 for($row=0;$row -lt 31;$row++){$error=Run75 'training/headobjective32-v11/error.bf' (Join75 @($id,(Bytes75 $vocab[$row].ID)));$rows.Add((Join75 @((Bytes75 '1'),$error,(Slice75 $bank (8*$row) 8))))}
 return ,(Run75 'training/wordcodec32-v1/reference-print.bf' (Join75 $rows.ToArray()))
}
function DecodeQA32([byte[]]$id){
 if($null -eq $id -or $id.Length -ne 2){throw 'QA decoder requires exactly two decimal bytes'}
 $valid=Run75 'training/abi32-v11/validate-slot.bf' $id;if($ascii.GetString($valid) -cne '0'){throw 'QA decoder invalid ID'}
 $nonBos=Run75 'training/headobjective32-v11/error.bf' (Join75 @($id,(Bytes75 '00')));if($ascii.GetString($nonBos) -cne '1'){throw 'QA decoder rejects BOS'}
 $bank=BankQA32;$decoded=Run75 'training/wordqa-codec32-v1/decode.bf' (Join75 @($bank,$id))
 CheckC76 'QA independent decimal key decoder' (ReferenceDecodeQA32 $id $bank) $decoded;return ,$decoded
}
function RecordsQA32($name,[byte[]]$text){
 $ids=EncodeQA32 $name $text;$records=Run75 'training/textdata32-v1/windows.bf' $ids
 $targets=Join75 @((Slice75 $ids 2 ($ids.Length-2)),(Bytes75 '01'));$context=Bytes75 '00000000';$reference=[Collections.Generic.List[byte[]]]::new()
 foreach($target in (PartsRef76 $targets 2)){$reference.Add((Join75 @($context,$target)));$context=Run75 'training/textdata32-v1/shift-reference.bf' (Join75 @($context,$target))}
 LongCheckT76 ($name+' independent word windows and EOS') (Join75 $reference.ToArray()) $records;Save75 ($name+'.word.records') $records;return ,$records
}
