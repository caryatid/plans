#!/bin/sh

seed=$(cat /dev/urandom | dd bs=255 count=1 2>/dev/null | tr \\0 \ )
count=0
int_keys=$(printf "%s\n" procedure procedure_index status)

_gen_hash() {
    echo -n $count$seed | sha1sum | cut -d' ' -f1 | tr -d '\n'
    count=$(( $count + 1 ))
}

_list_hashes () {
    find "$_D" -type d | grep '../.\{38\}$' | sed "s#$_D##" | sed "s#/##g" | uniq
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
    key_match="$1"; test -z "$key_match" && key_match='.*'
    match="$2"; test -z "$match" && match='.*'
    for h in $(_list_hashes)
    do
        for k in $(_list_hkeys $h | grep "$key_match")
        do 
            grep -q "$match" $(_get_hkey $h $k) || continue
            echo $h $k $(_get_key $h $k | head -n1 | cut -c-33) 
        done
    done
}


_parse_key () {
    test -z "$1" && return 1
    local hash=$1
    local n=${2:-'.*'}
    local key=''
    case "$n" in
    +*)
        key=$(echo "$n" | cut -c2-)
        _get_key $1 "$key" >/dev/null
        ;;
    *)
        key=$(_list_hkeys $hash | grep "^$n\$")
        ;;
    esac
    _return_parse "$key" "$n"
}

_parse_hash () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    case "$h" in
    *:*) # key:match
        local key=$(echo $h | cut -d':' -f1)
        local match=$(echo $h | cut -d':' -f2)
        hash=$(_match_key "$key" "$match" )
        ;;
    +*)  # new hash, .name
        hash=$(_new_hash $(echo "$h" | cut -c2-))
        ;;
    =*)  # use this hash exactly as is ( no parsing )
        hash=$(echo "$h" | cut -c2-)
        ;;
    *)   # prefix hash match
        hash=$(_match_hash $h)
        ;;
    esac
    _return_parse "$hash" "$h"
}

_get_hdir() {  
    prefix=$(echo $1 | cut -c-2)
    suffix=$(echo $1 | cut -c3-)
    hdir="$_D/$prefix/$suffix"
    mkdir -p "$hdir"
    echo -n $hdir
}

_get_hkey() {  
    test -z "$2" && { echo must provide key; return 1 ;}
    hkey=$(_get_hdir "$1")/$2
    test -f "$hkey" || touch "$hkey"
    echo -n "$hkey"
}

_new_hash () {
    test -z "$1" && { echo provide a name; return 1 ;}
    hash=$(_gen_hash)
    echo "$@" >$(_get_hkey $hash name)
    date -Ins >$(_get_hkey $hash creation_time)
    echo $hash
}

_rm_hash () {
    rm -Rf $(_get_hdir $1)
}

_edit_key () {
    $EDITOR "$(_get_hkey $1 $2)"
}

_get_key () {
    key=name
    test -n "$2" && key=$2
    cat "$(_get_hkey $1 $key)" 
}

_set_key () {
    test -z "$2" && echo must provide key && return 1
    { echo "$int_keys" | grep -q "$2" ;} && \
        echo $2 is an internal key && return 1
    cat - >"$(_get_hkey $1 $2)"
}

case "$1" in
-D*)
    _D="${1#-D}"
    shift
    ;;
*)
    _D=./.hash
    ;;
esac

. ./config.sh


cmd=key
test -n "$1" && { cmd=$1; shift ;}
case "$cmd" in
list-hashes)
    _parse_hash ''
    ;;
id)
    hash=$(_parse_hash "$1") || _err_multi hash "$hash" $?
    printf '%s\n' $hash 
    ;;
delete)
    hash=$(_parse_hash "$1") || _err_multi hash "$hash" $?
    _rm_hash $hash
    ;;
key)
    hash=$(_parse_hash "$1") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    _get_key $hash "$key"
    ;;
set)  
    hash=$(_parse_hash "$1") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    _set_key $hash "$key"
    ;;
edit)
    hash=$(_parse_hash "$1") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    _edit_key $hash "$key"
    ;;
parse-hash)
    _parse_hash "$1"
    ;;
parse-key)
    hash=$(_parse_hash "$1") || _err_multi hash "$hash" $?
    _parse_key $hash "$2"
    ;;
*)  # this help
    echo you are currently helpless
    ;;
esac

