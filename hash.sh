#!/bin/sh


###
# I/O

# input:
#     value: anything that could go in a file
#     hash-list: list of "hash | append-data"

# output:
#     handler-fail: <error-msg>
#     hash-list: list of "hash | append-data"
#     hash: single hash
#     value: anything that could go in a file

seed=$(cat /dev/urandom | dd bs=255 count=1 2>/dev/null | tr \\0 \ )
count=0
CORE=./core.sh
TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT

###
# data:

# - hash: directory structure 
#     - id: sha1 2/38 nested directory ala git
#     - [key]: set of files in sha dir
HDIR=.hash
echo "$1" | grep -q "^-D" && { HDIR=$(echo "$1" | cut -c3-); shift ;}
test -d "$HDIR" || mkdir -p "$HDIR"

# - key: filename in sha1 dir
#     - name: string 
#     - value: anything that can go in a file

###
# queries:

# - hash: [mn].* | hash-prefix
#     - key-match: k.<key-pattern>:<value_pattern>
#     - new: n.
#     - no-parse: ..<full sha1>
#     - hash-prefix-pattern: matches hash prefixes
_parse_hash () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    echo "$h" | grep -q '^f_' && { h=${h#??}; FROM_STDIN=1 ;}
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    case $prefix in 
    m.) 
        echo "$pattern" | grep -q -v ':' && pattern="${pattern}:"
        local key=$(echo "$pattern" | cut -d':' -f1)
        local match=$(echo "$pattern" | cut -d':' -f2)
        hash=$(_match_key "$key" "$match")
        ;;
    e.)
        for h in $(_list_hashes)
        do
            test -z "$(_list_hkeys $h)" && echo $h
        done >$TMP/empty
        hash=$(head -n1 $TMP/empty)
        test -z "$head" && hash=$(_new_hash)
        ;;
    n.)  
        hash=$(_new_hash)
        test -n "$pattern" && _get_key $hash "$pattern" >/dev/null
        ;;
    ..)  
        hash=$pattern
        ;;
    *)
        hash=$(_match_hash "$h")
        ;;
    esac
    $CORE return-parse "$hash" "$h"
}


# - key: [sm].* | key-prefix
#     - singleton: s.<key>
#     - key-pattern: m.<key-pattern>
#     - exact; <string>
_parse_key () {
    local key=''
    test -z "$1" && return 1
    local hash=$1
    local k="$2"
    local prefix=$(echo "$k" | cut -c-2)
    local pattern=$(echo "$k" | cut -c3-)
    case $prefix in
    n.)
        if test -n "$pattern"
        then
            _get_key $hash "$pattern" >/dev/null
            key="$pattern"
        fi
        ;;
    m.)
        pattern=${pattern:-'.*'}
        key=$(_list_hkeys $hash | grep "$pattern")
        ;;
    *)
        k=${k:-'.*'}
        key=$(_list_hkeys $hash | grep "^$k\$")
        ;;
    esac
    $CORE return-parse "$key" "$k"
}

HASH_LIST=''  # cache of hashlist indicator
_list_hashes () {
    test -n "$HASH_LIST" && { cat $TMP/hashes; return 0 ;}
    if test -z "$FROM_STDIN"
    then
        find $HDIR -type d | grep -o '../.\{38\}$' | tr -d '/' 
    else
        cat - | xargs -L1 | cut -d'|' -f1
    fi | tee $TMP/hashes
    HASH_LIST=1    
}

_list_hkeys () {
    ls "$(_get_hdir $1)" | sort | xargs -L1
}

_match_hash () {
    for h in $(_list_hashes)
    do
        case $h in
        $1*)
            echo $h
            ;;
        esac
    done 
}

_match_key () {
    key_pattern=${1:-'.*'}
    val_pattern=${2:-'.*'}
    for h in $(_list_hashes)
    do
        _list_hkeys $h | grep "^${key_pattern}\$" >$TMP/hkeys
        while read k
        do 
            hkey=$(_get_hkey $h "$k")
            test -s "$hkey" || continue
            grep -q -v "$val_pattern" "$hkey" && continue
            echo $h | _append "$k" 12 | _append @"$k"
        done <$TMP/hkeys
    done 
}

### operations
_gen_hash () {
    echo -n $count$seed | sha1sum | cut -d' ' -f1 | tr -d '\n'
    count=$(( $count + 1 ))
}

_get_hdir () {
    test $(expr length "$1") -eq 40 || { echo bad hash "$1"; return 1 ;}
    prefix=$(echo $1 | cut -c-2)
    suffix=$(echo $1 | cut -c3-)
    hdir="$HDIR/$prefix/$suffix"
    mkdir -p "$hdir"
    echo -n $hdir
}

_get_hkey () {
    test -z "$2" && return 1
    hdir=$(_get_hdir "$1") || return 1
    hkey="$hdir/$2"
    test -f "$hkey" || touch "$hkey"
    echo -n "$hkey"
}

_new_hash () {
    hash=$(_gen_hash)
    _get_hdir $hash >/dev/null
    echo $hash
}

_rm_hash () {
    rm -Rf $(_get_hdir $1)
}

_edit_key () {  
    local hkey=$(_get_hkey $1 "$2")
    $EDITOR "$hkey"
}

_get_key () {
    test -z "$2" && return 1
    key=$(_get_hkey $1 "$2")
    cat "$key"
}

_set_key () {
    test -z "$2" && echo must provide key && return 1
    local hkey=$(_get_hkey $1 "$2")
    cat - >"$hkey"
    echo $1
}

_append () {
    local lookup='';
    local msg="$1"; local width=${2:-17}
    echo $msg | grep -q '^@' && lookup=true && msg=$(echo $msg | cut -c2-)
    while read hl
    do
        echo "$hl" | grep -q -v '|$' && hl=$hl'|'
        local h=$(echo $hl | cut -d'|' -f1 | xargs)
        local m=''
        if test -n "$lookup"
        then
            m=$(_get_key $h "$msg")
        else
            m=$(echo -n "$msg" | tr \\n ' ')
        fi
        printf '%s%-*.*s|\n' "$hl" "$width" "$width" "$m" 
    done
}

_handle_hash () {
    local header=$($CORE make-header hash "$2")
    hash=$(_parse_hash "$1") || { $CORE err-msg "$hash" "$header" $?; exit $? ;}
}

_handle_hash_key () {  
    _handle_hash "$1" "$3"
    local header=$($CORE make-header key "$3")
    key=$(_parse_key $hash "$2") || { $CORE err-msg "$key" "$header" $?; exit $? ;}
}


###
# commands: <output>

cmd=key
test -n "$1" && { cmd=$1; shift ;}
case "$cmd" in
# null:
#     - name: delete
delete)
    _handle_hash "$1"
    _rm_hash $hash
    ;;
#     - name: delete-key
delete-key)
    _handle_hash_key "$1" "$2"
    hkey=$(_get_hkey $hash "$key")
    rm "$hkey"
    ;;
#     - name: edit-key
edit)
    _handle_hash_key "$1" "$2"
    _edit_key $hash "$key"
    ;;
# hash-list:
#     - name: list-hashes
list-hashes)
    _list_hashes 
    ;;
#     - name: append
#       args: <value query> width 
append)
    _append "$@"
    ;;
# hash:
#     - name: id
id)
    _handle_hash "$1"
    echo $hash
    ;;
#     - name: set-key
#       stdin: value
set)  
    _handle_hash_key "$1" "$2"
    _set_key $hash "$key"
    ;;
# value:
#     - name: get-key
key)
    _handle_hash_key "$1" "$2"
    _get_key $hash "$key"
    ;;
parse-hash)
    _handle_hash "$1"
    echo $hash
    ;;
parse-key)
    _handle_hash_key "$@"
    echo "$key"
    ;;
*)
    echo you are currently helpless
    ;;
esac

