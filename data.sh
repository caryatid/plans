#!/bin/sh

###
# I/O

# input:
#     hash-list

# output:
#     handler-fail
#     hash-list
#     int
#     value
#     bool

CORE=./core.sh
TMP=$(mktemp -d)
trap 'rm -Rf $TMP' EXIT

###
# data:

#####
# TODO kinda putting this everywhere
HDIR=.hash
echo "$1" | grep -q "^-D" && { HDIR=$(echo "$1" | cut -c3-); shift ;}
test -d "$HDIR" || mkdir -p "$HDIR"
HASH="./hash.sh -D$HDIR"
#####
# - list: 2 keys in hash entry
#     - name: string
#     - index: int in key, <name>.i
#     - ordered referencs: data in the key <name>
# - set: 1 key in hash entry
#     - name: string
#     - references: data in key <name>
# - reflist: 1 key in hash entry
#     - name: string
#     - ordered name reference pairs: first 40 chars are ref; rest to \n is the key
# - boolean: 1 key in hash entry
#     - name: string
#     - true|false: if key <name> has data then true, else false
# - executable: 2 keys in hash entry
#     - name: string
#     - interpreter: <name>.x
#     - source: data in the key <name>
        


###
# queries:

# - hash: 
#     - <hash query>
# - index: [sec].* | <int> | +1
#     - start: s.<int>
#     - end: e.<int>
#     - current: c.<int>
#     - current: <int>
#     - +1 := null
# - ref: [kv].*
#     - key: <regex>
#     - value: <hash query> # filtered by ref values
# - boolean: [tfx]
#     - true: anything in file
#     - false: empty file
#     - toggle: flips file
_parse_list_idx () {
    local hash=$1
    local key="$2"
    local new_idx="$3"
    local max=$(_list_len $hash "$key")
    local idx=$($HASH key ..$hash "n.$key.i")
    local pattern=0
    echo "$new_idx" | grep -q '^.\.' && pattern=${new_idx#??}
    test -z "$pattern" && pattern=0
    case "$new_idx" in
    s.*)
        idx=$pattern
        ;;
    e.*)
        idx=$(( $max + 1 - $pattern ))
        ;;
    c.*)
        idx=$(( $idx + $pattern ))
        ;;
    '')
        idx=$(( $idx + 1 ))
        ;;
    *)
        idx=$(( $idx + $new_idx ))
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
    local r="$3"
    local prefix=$(echo "$r" | cut -c-2)
    local pattern=$(echo "$r" | cut -c3-)
    case $prefix in
    k.)
        refname=$(_match_ref $hash "$key" "$pattern" | cut -d'|' -f2)
        ;;
    v.)
        local ids=$(_match_ref $hash "$key" | cut -d'|' -f1 | $HASH id f_"$pattern")
        test $? -eq 1 && return 1
        for h in $(echo "$ids" | cut -d'|' -f1)
        do
            _match_ref $hash "$key" $h
        done >$TMP/rnames
        refname=$(cat $TMP/rnames)
        ;;
    n.)
        refname=$(_match_ref $hash "$key" "$pattern")
        if test -z "$refname"
        then
            _ref_set $hash "$key" "$pattern" >/dev/null
            refname=$(_match_ref $hash "$key" "$pattern" | cut -d'|' -f2)
        else
            refname=$(echo $refname)
        fi
        ;;
    *)
        refname=$(_match_ref $hash "$key")
        ;;
    esac
    refname=$(echo "$refname" | cut -d'|' -f2)
    $CORE return-parse "$refname" "$r"
}

_ref_set () {
    local hash=$1; local key="$2"; local ref="$3"; local h=$4
    test $(expr length "$h") -eq 40 || h=$(printf '0%0.0s' $(seq 40))
    $HASH key ..$hash "n.$key" | grep -v "$ref" >$TMP/reftmp
    echo "$h|$ref" >>$TMP/reftmp
    cat $TMP/reftmp | $HASH set ..$hash "n.$key"
}

_ref_rem () {
    local hash=$1; local key="$2"; local ref="$3"
    $HASH key ..$hash "n.$key" | grep -v "$ref" >$TMP/reftmp
    cat $TMP/reftmp | $HASH set ..$hash "n.$key"
}
        
_match_ref () {
    local hash=$1; local key="$2"; local pattern=${3:-'.*'}
    $HASH key ..$hash "n.$key" | grep "$pattern"
}

_set_list_find () {
    local thash=$1; local shash=$2; local name="$3"
    local idx=$($HASH key ..$thash "n.$name" | grep -n $shash | cut -d':' -f1)
    test -z "$idx" && return 1
    echo $idx
    return 0
} 
    
_list_range () {
    local hash=$1; local name="$2"; local lower=$3; local upper=$4
    test $lower -eq 0 && lower=1
    local sed_e=$(printf '%s,%sp' $lower "$upper")
    $HASH key ..$hash "n.$name" | sed -n "$sed_e"
}

_list_index () {
    local hash=$1; local name="$2"; local index=$3
    test $index -eq 0 && index=1
    local sed_e=$(printf '%sp' $index)
    $HASH key ..$hash "n.$name" | sed -n "$sed_e"
}

_list_len () {
    local hash=$1; local name="$2"
    $HASH key ..$hash "n.$name" | wc -l
}

### operations
_bool_set () {
    local hash=$1; local name="$2"
    case "$3" in 
    false)
        echo -n '' | $HASH set ..$hash n.$name
        ;;
    true)
        echo true | $HASH set ..$hash n.$name
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
    test -n "$($HASH key ..$hash n.$name)" && echo true && return 0 
    echo false
    return 1
}

_set_get () {
    local hash=$1; local name="$2"
    $HASH key ..$hash "n.$name"
}

_set_add () {
    local thash=$1; local shash=$2; local name="$3"
    $HASH key ..$thash "n.$name" >$TMP/set
    echo $shash $(cat $TMP/set) | tr ' ' '\n' | sort | uniq \
        | $HASH set ..$thash "n.$name"
}

_list_insert () {
    local thash=$1; local shash=$2; local name="$3"; local idx=$4
    $HASH key ..$thash "n.$name" >$TMP/list
    echo $(head -n$idx $TMP/list) $shash $(tail -n+$(( $idx + 1 )) $TMP/list) | tr ' ' '\n' \
        | $HASH set ..$thash "n.$name"
}

_set_list_rem () {
    local thash=$1; local shash=$2; local name="$3"
    $HASH key ..$thash "n.$name" >$TMP/set
    cat $TMP/set | grep -v $shash | $HASH set ..$thash "n.$name"
}

_list_set_index () {
    local hash=$1; local name="$2"; local idx=$3
    echo $idx | $HASH set ..$hash "n.$name.i"
    echo $idx
}

_exe_set_interpreter () {
    local hash=$1; local name="$2"
    $HASH set ..$hash "n.$name.x"
}

_execute () {
    local hash=$1; local name="$2"
    local interpreter=$($HASH key ..$hash "n.$name.x")
    interpreter=${interpreter:-sh}
    # TODO likely need to be "smarter" here
    $HASH key ..$hash "n.$name" | $interpreter
}
    
_reap_souls () {
    local hash=$1; local name="$2"
    local exists=$($HASH list-hashes)
    _set_get $hash $name | grep -e"$exists" >$TMP/set
    $HASH set ..$hash "n.$name" <$TMP/set
}

_handle_hash () {
    local header=$($CORE make-header hash "$2")
    hash=$($HASH parse-hash "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}

_handle_hash_key () {
    _handle_hash "$1" "$3"
    local header=$($CORE make-header key "$3")
    key=$($HASH parse-key ..$hash "$2") || { $CORE err-msg "$key" "$header" $?; exit 1 ;}
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
            { $CORE err-msg "$index" "$header" $?; exit 1 ;}
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
              { $CORE err-msg "$refname" "$header" $?; exit 1 ;}
}

_handle_target_source_key_refname () {  
    _handle_hash "$1" "$5"; target=$hash
    _handle_hash "$2" "$5"; source=$hash
    _handle_hash_key $target "$3" "$5"
    _handle_hash_key_refname $target "$key" "$4" "$5"
}

###
# commands: <output>

cmd=get
test -n "$1" && { cmd=$1; shift ;}
case $cmd in 
# null
#     - name: sadd
#       args:
#         target: <hash query>
#         source: <hash query>
#         key: <key query>
sadd)
    _handle_target_source_key "$@"
    _set_add $target $source "$key"
    ;;
#     - name: srem
#       args:
#         target: <hash query>
#         source: <hash query>
#         key: <key query>
#     - name: lrem
#       args:
#         target: <hash query>
#         source: <hash query>
#         key: <key query>
srem|lrem)
    _handle_target_source_key "$@"
    _set_list_rem $target $source $key
    ;;
#     - name: linsert
#       args:
#         target: <hash query>
#         source: <hash query>
#         key: <key query>
#         position: <index query>
linsert)
    _handle_target_source_key_index "$@"
    _list_insert $target $source "$key" $index
    ;;
#     - name: remove-non-existent
#       args:
#         hash: <hash query>
#         key: <key query>
remove-non-existent)
    _handle_hash_key "$@"
    _reap_souls $hash $key
    ;;
#     - name: set-interpreter
#       args:
#         hash: <hash query>
#         key: <key query>
set-interpreter)
    _handle_hash_key "$@"
    _exe_set_interpreter $hash $key
    ;;

# hash-list
#     - name: smembers
#       args:
#         hash: <hash query>
#         key: <key query>
smembers)
    _handle_hash_key "$@"
    _set_get $hash "$key"
    ;;
#     - name: lrange
#       args:
#         hash: <hash query>
#         key: <key query>
#         start: <index query>
#         stop: <index query>
lrange)
    _handle_hash_key_lower_upper "$1" "$2" "${3:-0}" "${4:-e.1}"
    _list_range $hash $key $lower $upper
    ;;
# int
#     - name: scard
#       args:
#         hash: <hash query>
#         key: <key query>
#     - name: llen
#       args:
#         hash: <hash query>
#         key: <key query>
scard|llen)
    _handle_hash_key "$@"
    _list_len $hash "$key"
    ;;
#     - name: lpos
#       args:
#         hash: <hash query>
#         key: <key query>
#         position: <index query>
lpos)
    _handle_hash_key_index "$@"
    _list_set_index $hash $key $index
    ;;
#     - name: lfind
#       args:
#         target: <hash query>
#         source: <hash query>
#         key: <key query>
#     - name: sfind
#       args:
#         target: <hash query>
#         source: <hash query>
#         key: <key query>
lfind|sfind)
    _handle_target_source_key "$@"
    _set_list_find $target $source $key
    ;;
# bool
#     - name: bool
#       args:
#         hash: <hash query>
#         key: <key query>
#         bool: true|false|toggle
bool)
    _handle_hash_key "$@"
    _bool_set $hash $key "$3"
    ;;
# hash
#     - name: lindex
#       hash: <hash query>
#       key: <key query>
#       position: <index query>
lindex)
    _handle_hash_key_index "$@"
    _list_index $hash $key $index
    ;;
# value
#     - name: execute
#       hash: <hash query>
#       key: <key query>
execute)
    _handle_hash_key "$@"
    _execute $hash $key
    ;;
ref)
    _handle_hash_key_refname "$@"
    _match_ref $hash "$key" $refname
    ;;
ref-add)
    _handle_target_source_key_refname "$@"
    _ref_set $target "$key" "$refname" $source
    ;;
ref-remove)
    _handle_hash_key_refname "$@"
    _ref_rem $hash "$key" "$refname"
    ;;
parse-refname)
    _handle_hash_key_refname "$@"
    echo $refname
    ;;
*)
    $HASH $cmd "$@"
esac

# 