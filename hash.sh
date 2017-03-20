#!/bin/sh

seed=$(dd if=/dev/urandom bs=255 count=1 2>/dev/null | tr \\0 \ )
count=0
CORE=./core.sh
TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT

HDIR="$HOME/.hash"
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
        local key=$(echo "$pattern" | cut -d':' -f1 | xargs)
        local match=$(echo "$pattern" | cut -d':' -f2 | xargs)
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
    k="${2:-.*}"
    echo "$k" | grep -q '^\.\.' && key="${k#..}"
    test -z "$key" && key=$(_list_hkeys $hash | grep "$k")
    $CORE return-parse "$key" "$k"
}

_list_hashes () {
    find $HDIR -type d | sed "s#^$HDIR##" | grep '../.\{38\}$' | tr -d '/' \
        | tee $TMP/hashes
}

_list_hkeys () {
    ls "$(_get_hdir $1)" | sort | tr '\n' '\0' | xargs -0 -n1 \
        | sed '/^[[:space:]]*$/d'
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
    local key_pattern=${1:-'.*'}
    local val_pattern="$2"
    for h in $(_list_hashes)
    do
        _list_hkeys $h | grep "$key_pattern" |  while read k
        do 
            local hkey=$(_get_hkey $h "$k")
            if test -n "$val_pattern"
            then 
                test ! -s "$hkey" && continue
                grep -q "$val_pattern" "$hkey" || continue
            fi
            echo $h | _append "$k" | _append @"$k" 
        done
    done 
}

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
    rm -Rf $(dirname $(_get_hdir $1))
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
    local h="$1"
    local header=$($CORE make-header key "$3")
    key=$(_parse_key $h "$2") || { $CORE err-msg "$key" "$header" $?; exit $? ;}
}

cmd="$1"
test -n "$1" && shift
case "$cmd" in
delete)
    _handle_hash "$1"
    _rm_hash $hash
    ;;
delete-key)
    _handle_hash "$1"
    _handle_hash_key $hash "$2"
    hkey=$(_get_hkey $hash "$key")
    rm "$hkey"
    ;;
edit)
    _handle_hash "$1"
    _handle_hash_key $hash "$2"
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
    _handle_hash "$1"
    _handle_hash_key $hash "$2"
    _set_key $hash "$key"
    ;;
key)
    _handle_hash "$1"
    _handle_hash_key $hash "$2"
    _get_key $hash "$key"
    ;;
parse-hash)
    _parse_hash "$@"
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

