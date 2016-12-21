#!/bin/sh

### parsing
_parse_list_idx () {  # Hash -> Name -> IdxQ -> ParseReturn
    test -z "$1" && echo must provide hash && return 1
    local hash=$1
    test -z "$2" && echo must provide name && return 1
    local key=$2
    new_idx="$3"
    local max=$(_list_len $hash $key)
    local idx=$($HASH_X key =$hash +$key.i)
    test -z "$idx" && idx=0
    case "$new_idx" in
    \[*\])  # from beginning
        idx=$(echo $new_idx | grep -o '[^][+]' | xargs printf '%s')
        ;;
    \]*\[)  # from end
        idx=$(( $max + 1 - $(echo $new_idx | grep -o '[^][+]' | \
                xargs printf '%s') ))
        ;;
    +*)  # from index
        idx=$(( $idx + $(echo $new_idx | grep -o '[^][+]' | xargs printf '%s') ))
        ;;
    '')  # idx +1
        idx=$(( $idx + 1 ))
        ;;
    *)
        idx=$new_idx
        ;;
    esac
    test $idx -lt 0 && idx=0
    test $idx -gt $max && idx=$max
    _return_parse "$idx" "$new_idx"
}

### query

_set_list_find () {  # Hash -> Hash -> Key -> Maybe Idx
    local thash=$1; local shash=$2; local name=$3
    local idx=$($HASH_X key =$thash +$name | grep -n $shash | cut -d':' -f1)
    test -z "$idx" && return 1
    echo $idx
    return 0
} 
    
_list_range () {  # Hash -> Key -> IdxQ -> IdxQ -> [Hash]
    local hash=$1; local name=$2; local lower=$3; local upper=$4
    test $lower -eq 0 && lower=1
    sed_e=$(printf '%s,%sp' $lower "$upper")
    $HASH_X key =$hash +$name | sed -n "$sed_e"
}

_list_index () {  # Hash -> Key -> IdxQ -> Hash
    local hash=$1; local name=$2; local index=$3
    test $index -eq 0 && index=1
    sed_e=$(printf '%sp' $index)
    $HASH_X key =$hash +$name | sed -n "$sed_e"
}

_list_len () {  # Hash -> Key -> Int
    local hash=$1; local name=$2
    $HASH_X key =$hash +$name | wc -l
}
    

### operations
_set_get () {  # Hash -> Key -> [Hash]
    local hash=$1
    local name=$2
    $HASH_X key =$hash $name 
}

_set_add () {  # Hash -> Hash -> Key -> Bool
    local thash=$1
    local shash=$2
    local name=$3
    local tmp=$(mktemp)
    $HASH_X key =$thash $name >$tmp
    echo $shash $(cat $tmp) | tr ' ' '\n' | sort | uniq \
        | $HASH_X set =$thash $name
    rm $tmp
}

_list_insert () {  # Hash -> Hash -> Key -> IdxQ -> Bool
    local thash=$1; local shash=$2; local name=$3; local idx=$4
    local tmp=$(mktemp)
    $HASH_X key =$thash +$name >$tmp
    echo $(head -n$idx $tmp) $shash $(tail -n+$(( $idx + 1 )) $tmp) | tr ' ' '\n' \
        | $HASH_X set =$thash $name
    rm $tmp
}

_set_list_rem () {  # Hash -> Hash -> Key -> Bool
    local thash=$1
    local shash=$2
    local name=$3
    local tmp=$(mktemp)
    $HASH_X key =$thash $name >$tmp
    cat $tmp | grep -v $shash | $HASH_X set =$thash $name
    rm $tmp
}

_list_set_index () {  # Hash -> Key -> IdxQ -> Idx
    local hash=$1; local name=$2; local idx="$3"
    echo $idx | $HASH_X set =$hash +$name.i
    echo $idx
}

_exe_set_interpreter () {  # Hash -> Key -> Bool
    local hash=$1; local name=$2
    $HASH_X set =$hash +$name.x
}

_execute () {  # Hash -> Key -> ?Exe?
    local hash=$1; local name=$2
    local interpreter=$($HASH_X key =$hash +$name.x)
    interpreter=${interpreter:-sh}
    $HASH_X key =$hash +$name | $interpreter
}
    
_verify_data () {  # Hash -> Key -> Bool
    local hash=$1
    local name=$2
    local tmp=$(mktemp)
    local exists=$($HASH_X list-hashes)
    _set_get $hash $name | grep -e"$exists" >$tmp
    $HASH_X set =$hash $name <$tmp
    rm $tmp
}

. ./config.sh

cmd=get
test -n "$1" && { cmd=$1; shift ;}
case $cmd in 
smembers)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    _set_get $hash $key
    ;;
sadd)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key $thash "$3") || _err_multi key "$key" $?
    _set_add $thash $shash $key
    ;;
slrem)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key $thash "$3") || _err_multi key "$key" $?
    _set_list_rem $thash $shash $key
    ;;
scard)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    _set_get $hash $key | wc -l
    ;;
llen)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    _list_len $hash $key
    ;;
lpos)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    idx=$(_parse_list_idx $hash $key "$3") || _err_multi idx "$idx" $?
    _list_set_index $hash $key "$idx"
    ;;
lindex)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    idx=$(_parse_list_idx $hash $key "${3:-+0}") || _err_multi idx "$idx" $?
    _list_index $hash $key $idx
    ;;
linsert)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key =$thash "$3") || _err_multi key "$key" $?
    idx=$(_parse_list_idx $thash $key "${4:-+0}") || _err_multi idx "$idx" $?
    _list_insert $thash $shash $key $idx
    ;;
lfind)
    thash=$($HASH_X parse-hash "$1") || _err_multi "target hash" "$thash" $?
    shash=$($HASH_X parse-hash "$2") || _err_multi "source hash" "$shash" $?
    key=$($HASH_X parse-key =$thash "$3") || _err_multi key "$key" $?
    _set_list_find $thash $shash $key
    ;;
lrange)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    sidx=$(_parse_list_idx $hash $key "${3:-[0]}") || _err_multi "start idx" "$sidx" $?
    eidx=$(_parse_list_idx $hash $key "${4:-]1[}") || _err_multi "end idx" "$eidx" $?
    _list_range $hash $key $sidx $eidx
    ;;
verify)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    _verify_data $hash __procedure__
    ;;
set-interpreter)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    _exe_set_interpreter $hash $key
    ;;
execute)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    _execute $hash $key
    ;;
parse-list)
    hash=$($HASH_X parse-hash "$1") || _err_multi hash "$hash" $?
    key=$($HASH_X parse-key =$hash "$2") || _err_multi key "$key" $?
    _parse_list_idx $hash $key $3
    ;;
*)
    $HASH_X $cmd "$@"
esac

