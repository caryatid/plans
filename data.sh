#!/bin/sh

CORE=./core.sh
TMP=$($CORE temp-dir)
trap 'rm -Rf $TMP' EXIT
HASH_X=./hash.sh

### parsing
_parse_list_idx () {  # Hash -> Name -> IdxQ -> ParseReturn
    test -z "$1" && echo must provide hash && return 1
    local hash=$1
    test -z "$2" && echo must provide name && return 1
    local key=$2
    local new_idx="$3"

    local max=$(_list_len $hash $key)
    local idx=$($HASH_X key =$hash +$key.i)
    local pattern=0
    echo "$new_idx" | grep -q '^.\.' && pattern=${new_idx#??}
    test -z "$pattern" && pattern=0

    case "$new_idx" in
    s.*)  # from beginning
        idx=$pattern
        ;;
    e.*)  # from end
        idx=$(( $max + 1 - $pattern ))
        ;;
    c.*)  # from current
        idx=$(( $idx + $pattern ))
        ;;
    '')  # current +1
        idx=$(( $idx + 1 ))
        ;;
    *)   # no prefx := current
        idx=$(( $idx + $new_idx ))
        ;;
    esac
    test -z "$idx" || test $idx -lt 0 && idx=0
    test $idx -gt $max && idx=$max
    $CORE return-parse "$idx" "$pattern"
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
_bool_set () {  # Hash -> Key -> SwitchString -> None
    local hash=$1
    local name=$2
    case "$3" in 
    false)
        echo false | $HASH_X set =$hash $name
        ;;
    true)
        echo true | $HASH_X set =$hash $name
        ;;
    toggle)
        if $(_bool_set $hash $name)
        then
            _bool_set $hash $name false >/dev/null
        else
            _bool_set $hash $name true >/dev/null
        fi
        ;;
    esac
    { $HASH_X key $hash $name | grep -i true ;} && return 0 
    echo false
    return 1
}

_set_get () {  # Hash -> Key -> [Hash]
    local hash=$1
    local name=$2
    $HASH_X key =$hash $name 
}

_set_add () {  # Hash -> Hash -> Key -> None
    local thash=$1
    local shash=$2
    local name=$3
    $HASH_X key =$thash $name >$TMP/set
    echo $shash $(cat $TMP/set) | tr ' ' '\n' | sort | uniq \
        | $HASH_X set =$thash $name
}

_list_insert () {  # Hash -> Hash -> Key -> IdxQ -> None
    local thash=$1; local shash=$2; local name=$3; local idx=$4
    $HASH_X key =$thash +$name >$TMP/list
    echo $(head -n$idx $TMP/list) $shash $(tail -n+$(( $idx + 1 )) $TMP/list) | tr ' ' '\n' \
        | $HASH_X set =$thash $name
}

_set_list_rem () {  # Hash -> Hash -> Key -> None
    local thash=$1
    local shash=$2
    local name=$3
    $HASH_X key =$thash $name >$TMP/set
    cat $TMP/set | grep -v $shash | $HASH_X set =$thash $name
}

_list_set_index () {  # Hash -> Key -> IdxQ -> Idx
    local hash=$1; local name=$2; local idx="$3"
    echo $idx | $HASH_X set =$hash +$name.i
    echo $idx
}

_exe_set_interpreter () {  # Hash -> Key -> None
    local hash=$1; local name=$2
    $HASH_X set =$hash +$name.x
}

_execute () {  # Hash -> Key -> ?Exe?
    local hash=$1; local name=$2
    local interpreter=$($HASH_X key =$hash +$name.x)
    interpreter=${interpreter:-sh}
    $HASH_X key =$hash +$name | $interpreter
}
    
_verify_data () {  # Hash -> Key -> None
    local hash=$1
    local name=$2
    local exists=$($HASH_X list-hashes)
    _set_get $hash $name | grep -e"$exists" >$TMP/set
    $HASH_X set =$hash $name <$TMP/set
}


cmd=get
test -n "$1" && { cmd=$1; shift ;}
case $cmd in 
smembers)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _set_get $hash $key
    ;;
sadd)
    thash=$($HASH_X parse-hash "$1") || $CORE err-msg  "$thash" "target hash" $?
    shash=$($HASH_X parse-hash "$2") || $CORE err-msg  "$shash" "source hash" $?
    key=$($HASH_X parse-key $thash "$3") || $CORE err-msg "$key" key $?
    _set_add $thash $shash $key
    ;;
slrem)
    thash=$($HASH_X parse-hash "$1") || $CORE err-msg  "$thash" "target hash" $?
    shash=$($HASH_X parse-hash "$2") || $CORE err-msg  "$shash" "source hash" $?
    key=$($HASH_X parse-key $thash "$3") || $CORE err-msg "$key" key $?
    _set_list_rem $thash $shash $key
    ;;
scard)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _set_get $hash $key | wc -l
    ;;
llen)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _list_len $hash $key
    ;;
bool)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _bool_set $hash $key "$3"
    ;;
lpos)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    idx=$(_parse_list_idx $hash $key "$3") || $CORE err-msg "$idx" idx $?
    _list_set_index $hash $key "$idx"
    ;;
lindex)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    idx=$(_parse_list_idx $hash $key "${3:-0}") || $CORE err-msg "$idx" idx $?
    _list_index $hash $key $idx
    ;;
linsert)
    thash=$($HASH_X parse-hash "$1") || $CORE err-msg  "$thash" "target hash" $?
    shash=$($HASH_X parse-hash "$2") || $CORE err-msg  "$shash" "source hash" $?
    key=$($HASH_X parse-key =$thash "$3") || $CORE err-msg "$key" key $?
    idx=$(_parse_list_idx $thash $key "${4:-0}") || $CORE err-msg "$idx" idx $?
    _list_insert $thash $shash $key $idx
    ;;
lfind)
    thash=$($HASH_X parse-hash "$1") || $CORE err-msg "$thash" "target hash" $?
    shash=$($HASH_X parse-hash "$2") || $CORE err-msg "$shash" "source hash" $?
    key=$($HASH_X parse-key =$thash "$3") || $CORE err-msg "$key" key $?
    _set_list_find $thash $shash $key
    ;;
lrange)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" $key ?
    sidx=$(_parse_list_idx $hash $key "${3:-0}") || $CORE err-msg "$sidx" "start idx" $?
    eidx=$(_parse_list_idx $hash $key "${4:-e.1}") || $CORE err-msg "$eidx" "end idx" $?
    _list_range $hash $key $sidx $eidx
    ;;
verify)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    _verify_data $hash __procedure__
    ;;
set-interpreter)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _exe_set_interpreter $hash $key
    ;;
execute)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _execute $hash $key
    ;;
parse-list)
    hash=$($HASH_X parse-hash "$1") || $CORE err-msg "$hash" hash $?
    key=$($HASH_X parse-key =$hash "$2") || $CORE err-msg "$key" key $?
    _parse_list_idx $hash $key $3
    ;;
*)
    $HASH_X $cmd "$@"
esac

