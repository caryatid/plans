#!/bin/sh

seed=$(cat /dev/urandom | dd bs=255 count=1 2>/dev/null | tr \\0 \ )
count=0

### parsing
_parse_key () {  # Hash -> KeyQ -> ParseReturn
    test -z "$1" && return 1
    local hash=$1
    local n=${2:-'.*'}
    local key=''
    case "$n" in
    +*)  # create
        key=$(echo "$n" | cut -c2-)
        _get_key $1 "$key" >/dev/null
        ;;
    *)  # regex
        key=$(_list_hkeys $hash | grep "^$n\$")
        ;;
    esac
    _return_parse "$key" "$n"
}

_parse_hash () {  # HashQ -> ParseReturn
    local hash=''
    local h="$1"
    test -n "$h" && shift
    echo "$h" | grep -q '^f_' && { h=${h#??}; FROM_STDIN=1 ;}
    case $h in 
    *:*) # key_match
        local key=$(echo $h | cut -d':' -f1)
        local match=$(echo $h | cut -d':' -f2)
        hash=$(_match_key "$key" "$match")
        ;;
    +*)  # create
        hash=$(_new_hash $(echo "$h" | cut -c2-))
        ;;
    =*)  # no_parse
        hash=$(echo $h | cut -c2-)
        ;;
    *)
        hash=$(_match_hash "$h")
        ;;
    esac
    _return_parse "$hash" "$h"
}

### query
_list_hashes () {  # [Hash]
    # TODO this is fucked if called in sequence with stdin input
    if test -z "$FROM_STDIN"
    then
        find "$_D" -type d | grep -o '../.\{38\}$' | tr -d '/'
    else
        cat - | xargs -L1 | cut -d' ' -f1
    fi
}

_list_hkeys () {  # Hash -> [Key]
    ls "$(_get_hdir $1)" | sort | xargs -L1
}


_match_hash () {  # HashPrefix -> [Hash]
    for h in $(_list_hashes)
    do
        case $h in
        $1*)
            echo $h | _append name
            ;;
        esac
    done 
}

_match_key () {  # Regex -> Regex -> [Hash]
    key_match=${1:-'.*'}
    pattern=${2:-'.*'}
    for h in $(_list_hashes)
    do
        for k in $(_list_hkeys $h | grep "$key_match")
        do 
            grep -q "$pattern" $(_get_hkey $h $k) || continue
            echo $h | _append $k x | _append $k
        done
    done 
}

### operations
_gen_hash () {  # Hash
    echo -n $count$seed | sha1sum | cut -d' ' -f1 | tr -d '\n'
    count=$(( $count + 1 ))
}

_get_hdir () {  # Hash -> Maybe KeyDirectory
    # TODO validate input
    prefix=$(echo $1 | cut -c-2)
    suffix=$(echo $1 | cut -c3-)
    hdir="$_D/$prefix/$suffix"
    mkdir -p "$hdir"
    echo -n $hdir
}

_get_hkey () {  # Hash -> Key -> Maybe KeyPath
    test -z "$2" && { echo must provide key; return 1 ;}
    hkey=$(_get_hdir "$1")/$2
    test -f "$hkey" || touch "$hkey"
    echo -n "$hkey"
}

_new_hash () {  # String -> Hash
    test -z "$1" && { echo provide a name; return 1 ;}
    hash=$(_gen_hash)
    echo "$@" >$(_get_hkey $hash name)
    date -Ins >$(_get_hkey $hash creation_time)
    echo $hash
}

_rm_hash () {  # Hash -> Bool
    rm -Rf $(_get_hdir $1)
}

_edit_key () {  # Hash -> Key -> Bool 
    # TODO verify the output of Bool here
    $EDITOR "$(_get_hkey $1 $2)"
}

_get_key () {  # Hash -> Key -> String
    key=name
    test -n "$2" && key=$2
    cat "$(_get_hkey $1 $key)" 
}

_set_key () {  # Hash -> Key -> Bool
    test -z "$2" && echo must provide key && return 1
    cat - >"$(_get_hkey $1 $2)"
}

_append () {
    local key=$1
    while read h
    do
        h_=$(echo $h | cut -d' ' -f1)
        if test -n "$2"
        then
            echo $h - $key
        else
            echo $h - $(_get_key $h_ $key | cut -c-33)
        fi
    done
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
hashq="$1"
case "$cmd" in
list-hashes)
    _list_hashes
    ;;
id)
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    printf '%s\n' $hash 
    ;;
delete)
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    _rm_hash $hash
    ;;
delete-key)
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    rm "$(_get_hkey $hash $key)"
    ;;
key)
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    _get_key $hash "$key"
    ;;
set)  
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    _set_key $hash "$key"
    ;;
edit)
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    key=$(_parse_key $hash "$2") || _err_multi key "$key" $?
    _edit_key $hash "$key"
    ;;
parse-hash)
    _parse_hash "$hashq"
    ;;
append)
    _append "$@"
    ;;
parse-key)
    hash=$(_parse_hash "$hashq") || _err_multi hash "$hash" $?
    _parse_key $hash "$2"
    ;;
*)
    echo you are currently helpless
    ;;
esac

