#!/bin/sh


seed=$(dd if=/dev/urandom bs=255 count=1 2>/dev/null | tr \\0 \ )
count=0
CORE=./core.sh
TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT

HDIR=.hash
echo "$1" | grep -q "^-D" && { HDIR=$(echo "$1" | cut -c3-); shift ;}
test -d "$HDIR" || mkdir -p "$HDIR"

_parse_hash () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    case $prefix in 
    m.) 
        echo "$pattern" | grep -q -v ':' && pattern="${pattern}:"
        local key=$(echo "$pattern" | cut -d':' -f1)
        local match=$(echo "$pattern" | cut -d':' -f2)
        hash=$(_match_key "$key" "$match")
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

_parse_key () {
    local key=''
    test -z "$1" && return 1
    local hash=$1
    local k="$2"
    local prefix=$(echo "$k" | cut -c-2)
    local pattern=$(echo "$k" | cut -c3-)
    case $prefix in
    m.)
        pattern=${pattern:-'.*'}
        key=$(_list_hkeys $hash | grep "$pattern")
        ;;
    *)
        k=${k:-'.*'}
        key=$(_list_hkeys $hash | grep "^$k\$")
        if test -z "$key"
        then
            _get_key $hash "$k" >/dev/null
            key="$k"
        fi
        ;;
    esac
    $CORE return-parse "$key" "$k"
}

HASH_LIST=''  # cache of hashlist indicator
              # could just check size of $TMP/hashes ?
_list_hashes () {
    test -n "$HASH_LIST" && { cat $TMP/hashes; return 0 ;}
    find $HDIR -type d | sed "s#^$HDIR##" | grep '../.\{38\}$' | tr -d '/' \
        | tee $TMP/hashes
    HASH_LIST=1
}

_list_hkeys () {
    ls "$(_get_hdir $1)" | sort | tr '\n' '\0' | xargs -0 -n1
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
            grep -q -v "$val_pattern" "$hkey" && continue
            echo $h | _append "$k" | _append @"$k" 
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
}

_append () {
    local lookup='';
    local msg="$1";
    echo $msg | grep -q '^@' && lookup=true && msg=$(echo $msg | cut -c2-)
    while read hl
    do
        local h=$(echo $hl | cut -d'|' -f1)
        local m=''
        if test -n "$lookup"
        then
            m=$(_get_key $h "$msg" | head -n1)
        else
            m=$(echo "$msg" | head -n1)
        fi
        printf '%s|%s\n' "$hl" "$m" 
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

cmd=$($CORE parse-cmd "$0" "$1") || { $CORE err-msg "$cmd" \
        "$($CORE make-header command hash)" $?; exit $? ;}


test -n "$1" && shift
case "$cmd" in
delete)
    _handle_hash "$1"
    _rm_hash $hash
    ;;
delete-key)
    _handle_hash_key "$1" "$2"
    hkey=$(_get_hkey $hash "$key")
    rm "$hkey"
    ;;
edit)
    _handle_hash_key "$1" "$2"
    _edit_key $hash "$key"
    ;;
list-hashes) 
    _list_hashes 
    ;;
append)
    _append "$@"
    ;;
id)
    _handle_hash "$1"
    echo $hash
    ;;
set)  
    _handle_hash_key "$1" "$2"
    _set_key $hash "$key"
    ;;
key)
    _handle_hash_key "$1" "$2"
    _get_key $hash "$key"
    ;;
parse-hash)
    _handle_hash "$1"
    echo $hash
    ;;
parse-key)
    _handle_hash "$1"
    test -n "$1" && shift
    _parse_key $hash "$@"
    ;;
*)
    echo you are currently helpless
    ;;
esac

