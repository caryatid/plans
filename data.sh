_parse_list_idx () {
    test -z "$1" && echo must provide hash && return 1
    local hash=$1
    test -z "$2" && echo must provide name && return 1
    local key=$2
    new_idx="$3"
    local max=$(_list_len $hash $key)
    local idx=$($HASH_X key $hash +$key.i)
    test -z "$idx" && idx=0
    case "$new_idx" in
    [*)
        idx=$(echo $new_idx | cut -c2-)
        ;;
    ]*)
        idx=$(( $max + 1 - $(echo $new_idx | cut -c2-) ))
        ;;
    +*)
        idx=$(( $idx + $(echo $new_idx | cut -c2-) ))
        ;;
    -*)
        idx=$(( $idx - $(echo $new_idx | cut -c2-) ))
        ;;
    =)
        idx=$idx 
        ;;
    '')
        idx=$(( $idx + 1 ))
        ;;
    *)
        idx=$new_idx
        ;;
    esac
    test $idx -lt 0 && idx=0
    test $idx -gt $max && idx=$max
    printf '%s\n' $idx
}

_set_get () {
    local hash=$1
    local name=$2
    local tmp=$(mktemp)
    $HASH_X key $hash $name 
}

_set_add () {
    local thash=$1
    local shash=$2
    local name=$3
    local tmp=$(mktemp)
    $HASH_X key $thash $name >$tmp
    echo $shash $(cat $tmp) | tr ' ' '\n' | sort | uniq \
        | $HASH_X set $thash $name
    rm $tmp
}

_set_rem () {
    local thash=$1
    local shash=$2
    local name=$3
    local tmp=$(mktemp)
    $HASH_X key $thash $name >$tmp
    cat $tmp | grep -v $shash | $HASH_X set $thash $name
    rm $tmp
}

_list_set_index () {
    local hash=$1; local name=$2; local idx="$3"
    echo $idx | $HASH_X set $hash +$name.i
    echo $idx
}

_list_insert () {
    local thash=$1; local shash=$2; local name=$3; local idx=$4
    local tmp=$(mktemp)
    $HASH_X key $thash +$name >$tmp
    echo $(head -n$idx $tmp) $shash $(tail -n+$(( $idx + 1 )) $tmp) | tr ' ' '\n' \
        | $HASH_X set $thash $name
    rm $tmp
}

_list_range () {
    local hash=$1; local name=$2; local lower=$3; local upper=$4
    test $lower -eq 0 && lower=1
    sed_e=$(printf '%s,%sp' $lower "$upper")
    $HASH_X key $hash +$name | sed -n "$sed_e"
}

_list_index () {
    local hash=$1; local name=$2; local index=$3
    test $index -eq 0 && index=1
    sed_e=$(printf '%sp' $index)
    $HASH_X key $hash +$name | sed -n "$sed_e"
}

_list_len () {
    local hash=$1; local name=$2
    $HASH_X key $hash +$name | wc -l
}

. ./config.sh

cmd=get
test -n "$1" && { cmd=$1; shift ;}
case $cmd in 
smembers)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    _set_get $hash $key
    ;;
sadd)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key $thash "$3") || _err_multi key "$key" $?
    _set_add $thash $shash $key
    ;;
srem)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key $thash "$3") || _err_multi key "$key" $?
    _set_rem $thash $shash $key
    ;;
scard)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    _set_get $hash $key | wc -l
    ;;
lpos)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    idx=$(_parse_list_idx $hash $key "${3:-=}") || _err_multi idx "$idx" $?
    _list_set_index $hash $key "$idx"
    ;;
lindex)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    idx=$(_parse_list_idx $hash $key "${3:-=}") || _err_multi idx "$idx" $?
    _list_index $hash $key $idx
    ;;
linsert)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key $thash "$3") || _err_multi key "$key" $?
    idx=$(_parse_list_idx $thash $key "${4:-=}") || _err_multi idx "$idx" $?
    _list_insert $thash $shash $key $idx
    ;;
lrange)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    sidx=$(_parse_list_idx $hash $key "${3:-[0}") || _err_multi "start idx" "$sidx" $?
    eidx=$(_parse_list_idx $hash $key "${4:-]1}") || _err_multi "end idx" "$eidx" $?
    _list_range $hash $key $sidx $eidx
    ;;
llen)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    _list_len $hash $key
    ;;
parse-list)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key $hash "$2") || _err_multi key "$key" $?
    _parse_list_idx $hash $key $3
    ;;
*)
    $HASH_X $cmd "$@"
esac

