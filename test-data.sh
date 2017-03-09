TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
DATA="./data.sh -D$TMP/.datas"

TOP=$($DATA ..id n.)

for x in $(seq 10); do $DATA add-set ..$TOP n. set ; done
for x in $(seq 10); do $DATA add-list ..$TOP n. list; done

for x in aa bbb ccc ddd 'ee ee' 'ff ff ff' ggggg hhhhh iii
do
    $DATA add-ref ..$TOP n. ref "$x"
done

cat <<'EOF' | $DATA ..set ..$TOP exe
echo this is run by data.sh
echo the local dir is $PWD
while test -n "$1"
do
    echo "argument: $1"
    shift
done
EOF

$DATA execute ..$TOP exe one two 'kitty boo'
echo 

$DATA parse-refname ..$TOP ref | while read r
do
    $DATA show-ref ..$TOP ref "$(echo $r | cut -d'|' -f1)"
done

for i in $(seq $($DATA ..len-list ..$TOP list))
do
    $DATA at-index-list ..$TOP list s.$i
    $DATA cursor-list ..$TOP list e.$i
done

$DATA range-list ..$TOP list s.2 e.3

$DATA bool ..$TOP bool toggle
$DATA bool ..$TOP bool false
$DATA bool ..$TOP bool true


$DATA show-set ..$TOP set | while read sm
do
    $DATA ..remove-set ..$TOP "$sm" set
done
$DATA ..show-list ..$TOP list | while read lm
do
    $DATA ..remove-list ..$TOP "$lm" list
done
$DATA ..show-refs ..$TOP ref | while read rm
do
    $DATA remove-ref ..$TOP "$(echo $rm | cut -d'|' -f2)" ref
done

