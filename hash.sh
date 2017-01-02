#!/bin/sh

seed=$(cat /dev/urandom | dd bs=255 count=1 2>/dev/null | tr \\0 \ )
count=0
CORE=./core.sh
TMP=$($CORE temp-dir)
trap 'rm -Rf $TMP' EXIT
HDIR=$($CORE hash-dir) || { $CORE hash-dir; HDIR=$($CORE hash-dir) ;} 
HASH_LIST=''  # cache of hashlist indicator

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
    $CORE return-parse "$key" "$n"
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
    $CORE return-parse "$hash" "$h"
}

### query
_list_hashes () {  # [Hash]
    test -n "$HASH_LIST" && { cat $TMP/hashes; return 0 ;}
    if test -z "$FROM_STDIN"
    then
        find $HDIR -type d | grep -o '../.\{38\}$' | tr -d '/' 
    else
        cat - | xargs -L1 | cut -d'|' -f1
    fi | tee $TMP/hashes
    HASH_LIST=1    
}

_list_hkeys () {  # Hash -> [Key]
    ls "$(_get_hdir $1)" | sort | xargs -L1
}


_match_hash () {  # HashPrefix -> [Hash]
    for h in $(_list_hashes)
    do
        case $h in
        $1*)
            echo $h | _append @name
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
            echo $h | _append $k | _append @$k
        done
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

_get_hkey () {  # Hash -> Key -> Maybe KeyPath
    test -z "$2" && { echo must provide key; return 1 ;}
    hkey=$(_get_hdir "$1")/$2 || return 1
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

_edit_key () {  
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

_append () {  # TODO a 'strip' command leavning only hash
    local lookup='';
    local msg="$1"; local width=$2
    echo $msg | grep -q '^@' && lookup=true && msg=$(echo $msg | cut -c2-)
    width=${width:-17}
    while read hl
    do
        echo "$hl" | grep -q -v '|$' && hl=$hl'|'
        local h=$(echo $hl | cut -d'|' -f1 | xargs)
        local m="$msg"
        m=$(echo -n "$m" | tr \\n ' ')
        test -n "$lookup" && m=$(_get_key $h $msg)
        printf '%s%*.*s|\n' "$hl" "$width" "$width" "$m" 
    done
}

_handle_hash () {  # query -> header
    local header=$($CORE make-header hash "$2")
    hash=$(_parse_hash "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}

_handle_hash_key () {  
    _handle_hash "$1" "$3"
    local header=$($CORE make-header key "$3")
    key=$(_parse_key $hash "$2") || { $CORE err-msg "$key" "$header" $?; exit 1 ;}
}

cmd=key
test -n "$1" && { cmd=$1; shift ;}
case "$cmd" in
list-hashes)
    _list_hashes 
    ;;
id)
    _handle_hash "$1" 'id'
    echo $hash
    ;;
delete)
    _handle_hash "$1"
    _rm_hash $hash
    ;;
delete-key)
    _handle_hash_key "$1" "$2"
    rm "$(_get_hkey $hash $key)"
    ;;
key)
    _handle_hash_key "$1" "$2"
    _get_key $hash "$key"
    ;;
set)  
    _handle_hash_key "$1" "$2"
    _set_key $hash "$key"
    ;;
edit)
    _handle_hash_key "$1" "$2"
    _edit_key $hash "$key"
    ;;
parse-hash)
    _handle_hash "$1"
    echo $hash
    ;;
append)
    _append "$@"
    ;;
parse-key)
    _handle_hash_key "$1" "$2"
    echo $key
    ;;
*)
    echo you are currently helpless
    ;;
esac


# TODO copy hash
