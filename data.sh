#!/bin/sh

CORE=./core.sh
TMP=$(mktemp -d)
trap 'rm -Rf $TMP' EXIT

HDIR=.hash
echo "$1" | grep -q "^-D" && { HDIR=$(echo "$1" | cut -c3-); shift ;}
test -d "$HDIR" || mkdir -p "$HDIR"
HASH="./hash.sh -D$HDIR"

_parse_list_idx () {
    local hash=$1
    local key="$2"
    local i=$3
    local max=$(_list_len $hash "$key")
    local idx=$($HASH ..key ..$hash "$key.i")
    local prefix=$(echo "$i" | cut -c-2)
    local pattern=$(echo "$i" | cut -c3-)
    test -z "$pattern" && pattern=0
    case "$prefix" in
    s.)
        idx=$pattern
        ;;
    e.)
        idx=$(( $max + 1 - $pattern ))
        ;;
    c.)
        idx=$(( $idx + $pattern ))
        ;;
    '')
        idx=$(( $idx + 1 ))
        ;;
    *)
        idx=$i
        ;;
    esac
    test -z "$idx" || test $idx -lt 0 && idx=0
    test $idx -gt $max && idx=$max
    $CORE return-parse "$idx" "$pattern"
}

_parse_refname () {
    local refname=''
    local hash=$1
    local key="$2"
    local pattern="${3:-.*}"
    local switch=""
    echo "$pattern" | grep -q '^v\.' && { switch=1; pattern="${pattern#??}" ;}
    refname=$(_match_ref $hash "$key" "$pattern" "$switch")
    test -z "$refname" && test -n "$3" && refname="$3"
    $CORE return-parse "$refname" "$r"
}

_match_ref () {
    local hash=$1; local key="$2"; local pattern=$3
    local switch=$4
    $HASH ..key ..$hash "$key" | while read rf
    do
        local hash=$(echo "$rf" | cut -d'|' -f1)
        local ref=$(echo "$rf" | cut -d'|' -f2)
        if test -z "$switch"
        then
            echo "$ref" | grep -q "$pattern" && echo "$ref|$hash"
        else
            echo $hash | grep -q "$pattern" && echo "$ref|$hash"
        fi
    done
    return 0
}

_ref_set () {
    local hash=$1; local key="$2"; local ref="$3"; local h=$4
    test $(expr length "$h") -eq 40 || h=$(printf '0%0.0s' $(seq 40))
    $HASH ..key ..$hash "$key" | grep -v "$ref" >$TMP/reftmp
    echo  "$h"\|"$ref">>$TMP/reftmp
    cat $TMP/reftmp | grep -v '^[[:space:]]*$' | $HASH ..set ..$hash "$key"
}

_ref_rem () {
    local hash=$1; local key="$2"; local ref="$3"
    $HASH ..key ..$hash "$key" | grep -v "$ref" >$TMP/reftmp
    cat $TMP/reftmp | $HASH ..set ..$hash "$key"
}
        
_set_list_find () {
    local thash=$1; local shash=$2; local name="$3"
    local idx=$($HASH ..key ..$thash "$name" | grep -n $shash | cut -d':' -f1)
    test -z "$idx" && return 1
    echo "$idx"
    return 0
} 
    
_list_range () {
    local hash=$1; local name="$2"; local lower=$3; local upper=$4
    test $lower -eq 0 && lower=1
    local sed_e=$(printf '%s,%sp' $lower $upper)
    $HASH ..key ..$hash "$name" | sed -n "$sed_e"
}

_list_index () {
    local hash=$1; local name="$2"; local index=$3
    test $index -eq 0 && index=1
    local sed_e=$(printf '%sp' $index)
    $HASH ..key ..$hash "$name" | sed -n "$sed_e"
}

_list_len () {
    local hash=$1; local name="$2"
    $HASH ..key ..$hash "$name" | wc -l
}

_bool_set () {
    local hash=$1; local name="$2"
    case "$3" in 
    false)
        echo -n '' | $HASH ..set ..$hash $name
        ;;
    true)
        echo true | $HASH ..set ..$hash $name
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
    test -n "$($HASH ..key ..$hash $name)" && echo true && return 0 
    echo false
    return 1
}

_set_add () {
    local thash=$1; local shash=$2; local name="$3"
    $HASH ..key ..$thash "$name" | grep -v $shash >$TMP/set
    echo $shash $(cat $TMP/set) | tr ' ' '\n' | $HASH ..set ..$thash "$name"
}

_list_insert () {
    local thash=$1; local shash=$2; local name="$3"; local idx=$4
    $HASH ..key ..$thash "$name" >$TMP/list
    echo $(head -n$idx $TMP/list) $shash $(tail -n+$(( $idx + 1 )) $TMP/list) | tr ' ' '\n' \
        | $HASH ..set ..$thash "$name"
}

_set_list_rem () {
    local thash=$1; local shash=$2; local name="$3"
    $HASH ..key ..$thash "$name" >$TMP/set
    cat $TMP/set | grep -v $shash | $HASH ..set ..$thash "$name"
}

_list_set_index () {
    local hash=$1; local name="$2"; local idx=$3
    echo $idx | $HASH ..set ..$hash "$name.i" >/dev/null
    $HASH ..key ..$hash "$name.i"
}

_exe_set_interpreter () {
    local hash=$1; local name="$2"
    $HASH ..set ..$hash "$name.x"
}

_execute () {
    local hash=$1; local name="$2"
    local interpreter=$($HASH ..key ..$hash "$name.x")
    interpreter=${interpreter:-sh}
    # TODO likely need to be "smarter" here
    $HASH ..key ..$hash "$name" | $interpreter
}
    
_reap_souls () {
    local hash=$1; local name="$2"
    local exists=$($HASH ..list-hashes)
    _set_get $hash $name | grep -e"$exists" >$TMP/set
    $HASH ..set ..$hash "$name" <$TMP/set
}

_handle_hash () {
    local header=$($CORE make-header hash "$2")
    hash=$($HASH ..parse-hash "$1") || { $CORE err-msg "$hash" "$header" $?; exit $? ;}
}

_handle_hash_key () {
    _handle_hash "$1" "$3"
    local header=$($CORE make-header key "$3")
    key=$($HASH ..parse-key ..$hash "$2") || { $CORE err-msg "$key" "$header" $?; exit $? ;}
}

_handle_target_source_key () {  
    _handle_hash "$1" "$4"; target=$hash
    _handle_hash "$2" "$4"; source=$hash
    _handle_hash_key $target "$3" "$4"
}

_handle_hash_key_index () {
    _handle_hash "$1" "$4"
    _handle_hash_key $hash "$2" "$4"
    local header=$($CORE make-header index "$4")
    index=$(_parse_list_idx $hash "$key" "$3") || \
            { $CORE err-msg "$index" "$header" $?; exit $? ;}
}

_handle_hash_key_lower_upper () {
    _handle_hash "$1" "$5"
    _handle_hash_key $hash "$2" "$5"
    _handle_hash_key_index $hash $key "$3" "$5"; lower=$index
    _handle_hash_key_index $hash $key "$4" "$5"; upper=$index
}

_handle_target_source_key_index () {  
    _handle_hash "$1" "$5"; target=$hash
    _handle_hash "$2" "$5"; source=$hash
    _handle_hash_key $target "$3" "$5"
    _handle_hash_key_index $target "$key" "$4" "$5"
}

_handle_hash_key_refname () {
    _handle_hash "$1" "$4"
    _handle_hash_key $hash "$2" "$4"
    local header=$($CORE make-header refname "$4")
    refname=$(_parse_refname $hash "$key" "$3") || \
              { $CORE err-msg "$refname" "$header" $?; exit $? ;}
}

_handle_target_source_key_refname () {  
    _handle_hash "$1" "$5"; target=$hash
    _handle_hash "$2" "$5"; source=$hash
    _handle_hash_key $target "$3" "$5"
    _handle_hash_key_refname $target "$key" "$4" "$5"
}

cmd=$($CORE parse-cmd "$0" "$1") || { $CORE err-msg "$cmd" \
        "$($CORE make-header command data)" $?; exit $? ;}

test -n "$1" && shift
case $cmd in 
show-set|show-refs|show-list)
    _handle_hash_key "$@"
    $HASH ..key ..$hash "$key"
    ;;
show-ref)
    _handle_hash_key_refname "$@"
    _match_ref $hash "$key" "$refname\$"
    ;;
add-set)
    _handle_target_source_key "$@"
    _set_add $target $source "$key"
    echo $source
    ;;
add-ref)
    _handle_target_source_key_refname "$@"
    _ref_set $target "$key" "$refname" $source
    _match_ref $hash "$key" "^$refname\$"
    ;;
add-list)
    _handle_target_source_key_index "$@"
    _list_insert $target $source "$key" $index
    echo $source
    ;;
remove-set|remove-list)
    _handle_target_source_key "$@"
    _set_list_rem $target $source "$key"
    echo $source
    ;;
remove-ref)
    _handle_hash_key_refname "$@"
    _ref_rem $hash "$key" "$refname"
    ;;
index-set|index-ref|index-list)
    _handle_target_source_key "$@"
    _set_list_find $target $source "$key"
    ;;
len-set|len-ref|len-list)
    _handle_hash_key "$@"
    _list_len $hash "$key"
    ;;
cursor-list)
    _handle_hash_key_index "$@"
    _list_set_index $hash $key $index
    ;;
range-list)
    _handle_hash_key_lower_upper "$1" "$2" "${3:-0}" "${4:-e.1}"
    _list_range $hash $key $lower $upper
    ;;
at-index-list)
    _handle_hash_key_index "$@"
    _list_index $hash "$key" $index
    ;;
bool)
    _handle_hash_key "$@"
    _bool_set $hash $key "$3"
    ;;
execute)
    _handle_hash_key "$@"
    _execute $hash $key
    ;;
set-interpreter)
    _handle_hash_key "$@"
    _exe_set_interpreter $hash $key
    ;;
parse-index)
    _handle_hash_key_index "$@"
    echo $index
    ;;
parse-refname)
    _handle_hash_key "$@"; shift; shift
    _parse_refname $hash $key "$@"
    ;;
*)
    $HASH ..$cmd "$@"
    ;;
esac

