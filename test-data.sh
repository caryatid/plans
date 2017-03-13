TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
DATA="./data.sh -D$TMP/.datas"

TOP=$($DATA id n.)

_random_range () {
    dd if=/dev/urandom bs=255 count=5 2>/dev/null | tr -dc "${1:-a-z}" \
        | fold -w${2:-80} 2>/dev/null | head -n1
}

_rnd_len () {
    local range="$1"; local max=${2:-12}
    _random_range "$range" $(( $RANDOM % $max + 1 ))
}

_rnd_words () {
    for _ in $(seq ${1:-7})
    do
        printf '%s ' $(_rnd_len "$2" "$3")
    done
}


for x in $(_rnd_words 100)
do
    $DATA add-ref ..$TOP n. ..ref "..$x"
done

for x in $(seq 100); do $DATA add-set ..$TOP n. ..set ; done
for x in $(seq 100); do $DATA add-list ..$TOP n. ..list; done

$DATA key ..$TOP ..ref

$DATA parse-refname ..$TOP ..ref | while read r
do
    $DATA show-ref ..$TOP ..ref "..$(echo $r | cut -d'|' -f1)"
done

cat <<'EOF' | $DATA set ..$TOP ..exe
echo this is run by data.sh
echo the local dir is $PWD
while test -n "$1"
do
    echo "argument: $1"
    shift
done
EOF

$DATA execute ..$TOP ..exe one two 'kitty boo'
echo 

for i in $(seq $($DATA len-list ..$TOP ..list))
do
    $DATA at-index-list ..$TOP ..list $i
    $DATA cursor-list ..$TOP ..list e.$i
done

$DATA range-list ..$TOP ..list 2 e.3

$DATA bool ..$TOP ..bool toggle
$DATA bool ..$TOP ..bool false
$DATA bool ..$TOP ..bool true

$DATA show-set ..$TOP ..set | while read sm
do
    $DATA remove-set ..$TOP "..$sm" ..set
done
$DATA show-list ..$TOP ..list | while read lm
do
    $DATA index-list ..$TOP "..$lm" ..list
done
$DATA show-list ..$TOP ..list | while read lm
do
    $DATA remove-list ..$TOP "..$lm" ..list
done
$DATA show-refs ..$TOP ..ref | while read rm
do
    $DATA remove-ref ..$TOP ..ref "..$(echo $rm | cut -d'|' -f2)"
done

